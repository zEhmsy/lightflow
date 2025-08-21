from flask import Flask, request, jsonify
from datetime import datetime

N = 8
MAX_N = 300

state = {
    'used': [60] * N,
    'b': [128] * N,
    's': [100] * N,
    'c': ['FF0000'] * N,
}

app = Flask(__name__)

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

@app.get('/state')
def get_state():
    return jsonify(state)

@app.get('/set')
def set_strip():
    try:
        which = int(request.args.get('which', 0))
        n = clamp(int(request.args.get('n', state['used'][0])), 1, MAX_N)
        b = clamp(int(request.args.get('b', state['b'][0])), 0, 255)
        s = clamp(int(request.args.get('s', state['s'][0])), 1, 1000)
        c = (request.args.get('c', state['c'][0]) or '').upper()
        c = ''.join(ch for ch in c if ch in '0123456789ABCDEF')[:6].ljust(6, '0')
    except Exception as e:
        return jsonify({'ok': False, 'error': str(e)}), 400

    if which == -1:
        state['used'] = [n] * N
        state['b'] = [b] * N
        state['s'] = [s] * N
        state['c'] = [c] * N
    elif 0 <= which < N:
        state['used'][which] = n
        state['b'][which] = b
        state['s'][which] = s
        state['c'][which] = c
    else:
        return jsonify({'ok': False, 'error': 'invalid strip index'}), 400

    return jsonify({'ok': True})

@app.get('/sync')
def sync():
    return jsonify({'ok': True, 'ts': datetime.utcnow().isoformat() + 'Z'})

if __name__ == '__main__':
# 0.0.0.0 per accettare connessioni anche dall'emulatore/telefono
    app.run(host='0.0.0.0', port=5000)