#include <WiFiS3.h>
#include <WiFiUdp.h>
#include <FastLED.h>
#include <ArduinoMDNS.h>

/* ==== WIFI ==== */
const char* WIFI_SSID = "Name WIFI";
const char* WIFI_PASS = "Password WIFI";

/* ==== LED / STRISCE ==== */
#define NUM_STRIPS   8
#define LED_TYPE     WS2812B
#define COLOR_ORDER  GRB
#define MAX_LEDS     300   // buffer per ciascuna strip

// PIN fissi: D2..D9
#define DATA_PIN_0   2
#define DATA_PIN_1   3
#define DATA_PIN_2   4
#define DATA_PIN_3   5
#define DATA_PIN_4   6
#define DATA_PIN_5   7
#define DATA_PIN_6   8
#define DATA_PIN_7   9

CRGB leds[NUM_STRIPS][MAX_LEDS];
CLEDController* ctrl[NUM_STRIPS];  // riferimenti ai controller FastLED

// Coda (head + livelli dietro in percentuali su 255)
const uint8_t TAIL_LEVELS[] = {255, 204, 179, 153, 128, 100, 80, 60, 20};
const uint8_t TAIL_LEN = sizeof(TAIL_LEVELS);

// Modalità per striscia
enum Mode : uint8_t { MODE_ANIM=0, MODE_SOLID=1 };

/* ==== Stato runtime per ogni striscia ==== */
uint16_t usedLEDs[NUM_STRIPS]    = {230,230,230,230,230,230,230,230};
uint8_t  brightness_[NUM_STRIPS] = {255,255,255,255,255,255,255,255}; // 0..255
uint32_t colorHex[NUM_STRIPS]    = {0xFF5000,0x00A0FF,0x00FF80,0xFF00A0,0xFFFF00,0x00FFFF,0xFFFFFF,0xFF8000};
int      dir_[NUM_STRIPS]        = {+1,+1,+1,+1,+1,+1,+1,+1};
int      head_[NUM_STRIPS]       = {0,0,0,0,0,0,0,0};
uint16_t speedLvl[NUM_STRIPS]    = {15,15,15,15,15,15,15,15}; // slider 1..50 (1 = max velocità)
uint32_t lastMs[NUM_STRIPS]      = {0,0,0,0,0,0,0,0};
Mode     mode_[NUM_STRIPS]       = {MODE_ANIM,MODE_ANIM,MODE_ANIM,MODE_ANIM,MODE_ANIM,MODE_ANIM,MODE_ANIM,MODE_ANIM};

/* ==== UDP DISCOVERY (stateless) ==== */
WiFiUDP udp;
const uint16_t DISCOVERY_PORT = 49999;
const char*    DISCOVERY_QUERY  = "LEDCTRL_DISCOVER_V1";
const char*    DISCOVERY_REPLY  = "LEDCTRL_REPLY_V1";
char devId[13];   // es. AB12CD
char hostnm[32];  // es. led-AB12CD

// ==== mDNS/Bonjour ====
WiFiUDP mdnsUdp;
MDNS mdns(mdnsUdp);

void startDiscovery() {
  uint8_t mac[6]; WiFi.macAddress(mac);
  snprintf(devId,  sizeof(devId),  "%02X%02X%02X", mac[3], mac[4], mac[5]);
  snprintf(hostnm,  sizeof(hostnm), "led-%s", devId);
  udp.begin(DISCOVERY_PORT);
}

void handleDiscovery() {
  int packetSize = udp.parsePacket();
  if (!packetSize) return;

  char buf[64]; int n = udp.read(buf, sizeof(buf)-1);
  if (n <= 0) return; buf[n] = 0;

  if (strstr(buf, DISCOVERY_QUERY)) {
    char json[256];
    IPAddress ip = WiFi.localIP();
    snprintf(json, sizeof(json),
      "{\"t\":\"%s\",\"id\":\"%s\",\"name\":\"%s\",\"ip\":\"%u.%u.%u.%u\",\"port\":80,"
      "\"api\":\"/state\",\"apiv\":1,\"strips\":8}",
      DISCOVERY_REPLY, devId, hostnm, ip[0], ip[1], ip[2], ip[3]);

    udp.beginPacket(udp.remoteIP(), udp.remotePort());
    udp.write((const uint8_t*)json, strlen(json));
    udp.endPacket();
  }
}

/* ==== WEB SERVER ==== */
WiFiServer server(80);

// HTML semplificato (immutato)
static const char HTML_PAGE[] =
"<!doctype html><html lang=\"it\"><head>"
"<meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
"<title>LED 8 Strisce</title>"
"<style>body{font-family:system-ui,Arial;margin:16px;background:#0b0b10;color:#e6e6ea}"
".wrap{display:grid;gap:16px;grid-template-columns:repeat(auto-fit,minmax(260px,1fr))}"
".card{background:#17171f;border:1px solid #2b2b38;border-radius:12px;padding:12px}"
"h1{font-size:18px;margin:0 0 12px}h2{font-size:15px;margin:0 0 8px}"
".row{display:flex;align-items:center;gap:8px;margin:8px 0}"
"label{min-width:82px;font-size:12px;color:#b8b8c3}"
"input[type=number]{width:90px;background:#0f0f15;color:#fff;border:1px solid #333;border-radius:6px;padding:6px}"
"input[type=range]{width:100%}input[type=color]{width:40px;height:26px;border:0;background:transparent}"
"select{background:#0f0f15;color:#fff;border:1px solid #333;border-radius:6px;padding:6px}"
"button{background:#2b60ff;color:#fff;border:0;border-radius:10px;padding:6px 10px;cursor:pointer}"
".row>span{font-variant-numeric:tabular-nums}.muted{color:#b8b8c3;font-size:12px}"
"</style></head><body><h1>Controller 8 Strisce LED (FastLED)</h1>"
"<div class=\"wrap\" id=\"wrap\"></div>"
"<div class=\"row\"><button onclick=\"sync()\">Sincronizza inizio</button></div>"
"<script>"
"const N=8;"
"function qs(id){return document.getElementById(id)}"
"function debounce(fn, wait){let t;return (...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),wait);};}"
"const pushSpeed=(i,s)=>fetch('/set?which='+i+'&s='+s).catch(()=>{});"
"const pushSpeedDeb=[...Array(N)].map((_,i)=>debounce(v=>pushSpeed(i,v),150));"
"function card(i){return `<div class='card'><h2>Striscia ${i}</h2>`+"
"`<div class='row'><label>Modalità</label><select id='m${i}'>`+"
"`<option value='anim'>Animazione</option>`+"
"`<option value='solid'>Tutti accesi</option>`+"
"`</select></div>`+"
"`<div class='row'><label>LED</label><input id='n${i}' type='number' min='1' max='300'><button onclick='apply(${i})'>Applica</button></div>`+"
"`<div class='row'><label>Bright</label><input id='b${i}' type='range' min='0' max='255'><span id='bv${i}'>0</span></div>`+"
"`<div class='row'><label>Velocità</label><input id='s${i}' type='range' min='1' max='50'><span id='sv${i}'>0 ms</span></div>`+"
"`<div class='muted'>(1 = più veloce, 50 = più lento)</div>`+"
"`<div class='row'><label>Colore</label><input id='c${i}' type='color'></div>`+`</div>`}"
"function bindLive(i){qs('b'+i).addEventListener('input',()=>qs('bv'+i).textContent=qs('b'+i).value);"
"qs('s'+i).addEventListener('input',e=>{const v=e.target.value;qs('sv'+i).textContent=v+' ms';pushSpeedDeb[i](v);});}"
"async function load(){const r=await fetch('/state');const j=await r.json();"
"for(let i=0;i<N;i++){qs('n'+i).value=j.used[i];qs('b'+i).value=j.b[i];qs('bv'+i).textContent=j.b[i];"
"qs('s'+i).value=j.s[i];qs('sv'+i).textContent=j.s[i]+' ms';qs('c'+i).value='#'+j.c[i];"
"qs('m'+i).value=(j.m[i]===1)?'solid':'anim';}}"
"async function apply(which){const p=new URLSearchParams();p.set('which',which);"
"p.set('n',qs('n'+which).value);p.set('b',qs('b'+which).value);p.set('s',qs('s'+which).value);"
"p.set('c',qs('c'+which).value.substring(1));p.set('mode',qs('m'+which).value);"
"await fetch('/set?'+p.toString());await load();}"
"async function sync(){await fetch('/sync');}"
"(function init(){let w=qs('wrap'),html='';for(let i=0;i<N;i++) html+=card(i);w.innerHTML=html;"
"for(let i=0;i<N;i++) bindLive(i);load();})();"
"</script></body></html>";

/* ==== UTILITY ==== */
uint32_t parseHexColor(const String& s, uint32_t def=0xFFFFFF){
  if (s.length()!=6) return def;
  return (uint32_t) strtoul(s.c_str(), nullptr, 16);
}
String urlDecode(const String& s){
  String o; o.reserve(s.length());
  for (uint16_t i=0;i<s.length();++i){
    char c=s[i];
    if (c=='%' && i+2<s.length()){
      auto hx=[&](char h)->int{ if(h>='0'&&h<='9')return h-'0'; if(h>='A'&&h<='F')return h-'A'+10; if(h>='a'&&h<='f')return h-'a'+10; return 0; };
      o += char((hx(s[i+1])<<4)|hx(s[i+2])); i+=2;
    } else if (c=='+') o+=' ';
    else o+=c;
  }
  return o;
}

/* ==== MAPPATURA VELOCITÀ ==== */
inline uint16_t intervalFromSpeed(uint16_t s){
  if (s <= 1) return 0;
  if (s >= 50) return 50;
  return s; // 2..49 -> 2..49 ms
}

/* ==== DISEGNO TAIL ==== */
inline void drawHeadTail(CRGB* buf, uint16_t L, int headPos, int direction, const CRGB& base, uint8_t bright){
  fill_solid(buf, L, CRGB::Black);
  for (uint8_t k=0;k<TAIL_LEN;++k){
    int p = headPos + ((direction>0)? -int(k) : int(k));
    if (p<0 || p>= (int)L) continue;
    CRGB c = base;
    c.nscale8_video(TAIL_LEVELS[k]);   // livello della coda
    c.nscale8_video(bright);           // brightness per-striscia
    buf[p]=c;
  }
}

/* ==== APPLY / SHOW ==== */
void applyImmediate(int which){ // which: 0..7 o -1=tutte
  auto drawOne = [&](int i){
    usedLEDs[i] = constrain(usedLEDs[i], 1, (uint16_t)MAX_LEDS);
    head_[i]    = constrain(head_[i], 0, (int)usedLEDs[i]-1);
    CRGB base; base.setColorCode(colorHex[i]);

    if (mode_[i] == MODE_SOLID) {
      CRGB c = base; c.nscale8_video(brightness_[i]);
      fill_solid(leds[i], usedLEDs[i], c);
      if (usedLEDs[i] < MAX_LEDS) fill_solid(leds[i] + usedLEDs[i], MAX_LEDS - usedLEDs[i], CRGB::Black);
    } else {
      drawHeadTail(leds[i], usedLEDs[i], head_[i], dir_[i], base, brightness_[i]);
      if (usedLEDs[i] < MAX_LEDS) fill_solid(leds[i] + usedLEDs[i], MAX_LEDS - usedLEDs[i], CRGB::Black);
    }
    ctrl[i]->showLeds(255);   // mostra SOLO questa striscia
  };

  if (which<0){ for(int i=0;i<NUM_STRIPS;i++) drawOne(i); }
  else drawOne(which);
}

/* ==== HTTP HELPERS ==== */
void sendJSON(WiFiClient& c, const String& body, int code=200){
  c.print("HTTP/1.1 "); c.print(code); c.println(" OK");
  c.println("Content-Type: application/json");
  c.println("Connection: close");
  c.println();
  c.print(body);
}
void sendHTML(WiFiClient& c, const char* html){
  c.println("HTTP/1.1 200 OK");
  c.println("Content-Type: text/html; charset=utf-8");
  c.println("Connection: close");
  c.println();
  c.print(html);
}
String getParam(const String& q, const String& k){
  String key=k+"="; int s=q.indexOf(key); if(s<0) return "";
  s+=key.length(); int e=q.indexOf('&',s); if(e<0) e=q.length();
  return urlDecode(q.substring(s,e));
}

/* ==== HTTP ROUTER ==== */
void handleHttp(){
  WiFiClient client = server.available();
  if (!client) return;

  // attesa headers
  uint32_t t0=millis();
  while(!client.available() && millis()-t0<2000) delay(1);
  if (!client.available()){ client.stop(); return; }

  String reqLine = client.readStringUntil('\r'); client.readStringUntil('\n');
  // consuma headers
  while (client.connected()){
    String h = client.readStringUntil('\r'); client.readStringUntil('\n');
    if (h.length()<=1) break;
  }

  int sp1=reqLine.indexOf(' '), sp2=reqLine.indexOf(' ', sp1+1);
  if (sp1<0||sp2<0){ client.stop(); return; }
  String url=reqLine.substring(sp1+1, sp2);
  String path=url, q=""; int qi=url.indexOf('?');
  if (qi>=0){ path=url.substring(0,qi); q=url.substring(qi+1); }

  if (path=="/" || path=="/index.html"){
    sendHTML(client, HTML_PAGE);
  }
  else if (path=="/favicon.ico"){
    client.println("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n");
  }
  else if (path=="/state"){
    // JSON: used[], b[], s[], c[], m[]
    String out="{\"used\":[";
    for(int i=0;i<NUM_STRIPS;i++){ out += String(usedLEDs[i]); if (i<NUM_STRIPS-1) out += ","; }
    out += "],\"b\":[";
    for(int i=0;i<NUM_STRIPS;i++){ out += String(brightness_[i]); if (i<NUM_STRIPS-1) out += ","; }
    out += "],\"s\":[";
    for(int i=0;i<NUM_STRIPS;i++){ out += String(speedLvl[i]); if (i<NUM_STRIPS-1) out += ","; }
    out += "],\"c\":[";
    for(int i=0;i<NUM_STRIPS;i++){
      char buf[7]; sprintf(buf,"%06X",(unsigned)colorHex[i]);
      out += "\""; out += buf; out += "\""; if (i<NUM_STRIPS-1) out += ",";
    }
    out += "],\"m\":[";
    for(int i=0;i<NUM_STRIPS;i++){ out += String((int)mode_[i]); if (i<NUM_STRIPS-1) out += ","; }
    out += "]}";
    sendJSON(client, out);
  }
  else if (path=="/set"){
    int which = getParam(q,"which").toInt(); // 0..7
    String nS=getParam(q,"n"), bS=getParam(q,"b"), sS=getParam(q,"s"), cS=getParam(q,"c"), mS=getParam(q,"mode");
    auto setOne=[&](int i){
      if (nS.length()) { usedLEDs[i] = constrain(nS.toInt(), 1, (int)MAX_LEDS); }
      if (bS.length()) { brightness_[i]= constrain(bS.toInt(), 0, 255); }
      if (sS.length()) {
        speedLvl[i] = constrain(sS.toInt(), 1, 50);  // 1..50 (1 = max)
        lastMs[i] = 0;                                // effetto immediato
      }
      if (cS.length()) { colorHex[i]   = parseHexColor(cS, colorHex[i]); }
      if (mS.length()) { mode_[i]      = (mS=="solid") ? MODE_SOLID : MODE_ANIM; }
      applyImmediate(i);  // mostra subito la singola striscia
    };
    if (which>=0 && which<NUM_STRIPS){ setOne(which); }
    sendJSON(client, "{\"ok\":true}");
  }
  else if (path=="/sync"){
    for (int i=0;i<NUM_STRIPS;i++){ head_[i]=0; dir_[i]=+1; }
    applyImmediate(-1);
    sendJSON(client, "{\"ok\":true}");
  }
  else{
    client.println("HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nNot found");
  }
  client.stop();
}

/* ==== SETUP / LOOP ==== */
void setup(){
  Serial.begin(115200);
  delay(100);

  // 8 controller (pin fissi compile-time)
  ctrl[0] = &FastLED.addLeds<LED_TYPE, DATA_PIN_0, COLOR_ORDER>(leds[0], MAX_LEDS);
  ctrl[1] = &FastLED.addLeds<LED_TYPE, DATA_PIN_1, COLOR_ORDER>(leds[1], MAX_LEDS);
  ctrl[2] = &FastLED.addLeds<LED_TYPE, DATA_PIN_2, COLOR_ORDER>(leds[2], MAX_LEDS);
  ctrl[3] = &FastLED.addLeds<LED_TYPE, DATA_PIN_3, COLOR_ORDER>(leds[3], MAX_LEDS);
  ctrl[4] = &FastLED.addLeds<LED_TYPE, DATA_PIN_4, COLOR_ORDER>(leds[4], MAX_LEDS);
  ctrl[5] = &FastLED.addLeds<LED_TYPE, DATA_PIN_5, COLOR_ORDER>(leds[5], MAX_LEDS);
  ctrl[6] = &FastLED.addLeds<LED_TYPE, DATA_PIN_6, COLOR_ORDER>(leds[6], MAX_LEDS);
  ctrl[7] = &FastLED.addLeds<LED_TYPE, DATA_PIN_7, COLOR_ORDER>(leds[7], MAX_LEDS);

  FastLED.clear(true);
  applyImmediate(-1);

  // Wi-Fi
  Serial.print("WiFi: "); Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED){ delay(300); Serial.print("."); }
  Serial.print("\nIP: "); Serial.println(WiFi.localIP());

  // Calcola hostnm/devId + avvia HTTP
  startDiscovery();     // <-- hostnm pronto (es. led-AB12CD)
  server.begin();

  // ===== mDNS / Bonjour =====
  if (!mdns.begin(WiFi.localIP(), hostnm)) {
    Serial.println("mDNS init FAILED");
  } else {
    Serial.print("mDNS: "); Serial.print(hostnm); Serial.println(".local");

    // Pubblica il servizio personalizzato (istanza = hostnm)
    // Sintassi corretta per ArduinoMDNS: addServiceRecord(instanza, tipo, proto, porta)
    mdns.addServiceRecord(hostnm, 80, MDNSServiceTCP, "ledctrl");
    mdns.addServiceRecord(hostnm, 80, MDNSServiceTCP, "http");
  }

  Serial.println("HTTP server pronto (http://<IP>/) | UDP discovery 49999 | mDNS attivo");
}

void loop(){
  handleHttp();
  handleDiscovery();  // facoltativo per Android/web; iOS userà mDNS

  uint32_t now = millis();

  for (int i=0;i<NUM_STRIPS;i++){
    if (mode_[i] == MODE_SOLID) continue; // SOLID: già mostrata da applyImmediate

    uint16_t interval = intervalFromSpeed(speedLvl[i]);
    if (interval == 0 || (now - lastMs[i] >= interval)){
      lastMs[i] = now;

      CRGB base; base.setColorCode(colorHex[i]);
      drawHeadTail(leds[i], usedLEDs[i], head_[i], dir_[i], base, brightness_[i]);
      if (usedLEDs[i] < MAX_LEDS) fill_solid(leds[i] + usedLEDs[i], MAX_LEDS - usedLEDs[i], CRGB::Black);

      // ping-pong
      head_[i] += dir_[i];
      if (head_[i] >= (int)usedLEDs[i]-1){ head_[i] = (int)usedLEDs[i]-1; dir_[i] = -1; }
      else if (head_[i] <= 0)             { head_[i] = 0;                 dir_[i] = +1; }

      ctrl[i]->showLeds(255);  // invia SOLO questa striscia
    }
  }

  // fondamentale per mDNS
  mdns.run();
}