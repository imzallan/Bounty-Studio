#!/usr/bin/env python3
"""Bounty Studio: local-only overlay server. Python 3.8+, standard library."""
import argparse
import bisect
import base64
import hashlib
import shutil
import struct
import subprocess
import tempfile
import time
import uuid
import copy
import datetime as dt
import json
import math
import os
from pathlib import Path
import re
import threading
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SERVER_DIRECTORY = Path(__file__).resolve().parent
PROJECT_ROOT = SERVER_DIRECTORY.parents[1]
SOURCE_MODE = (PROJECT_ROOT / "src" / "BountyStudio.Web" / "overlay.html").is_file()
ROOT = PROJECT_ROOT if SOURCE_MODE else SERVER_DIRECTORY
WEB_ROOT = ROOT / "src" / "BountyStudio.Web" if SOURCE_MODE else ROOT
TOOLS_ROOT = ROOT / "assets" / "ffmpeg" if SOURCE_MODE else ROOT / "tools"
HTML = (WEB_ROOT / "overlay.html" if SOURCE_MODE else ROOT / "251vqzs.html").read_bytes()
if SOURCE_MODE:
    version_text = (PROJECT_ROOT / "VERSION").read_text(encoding="utf-8").strip().split(".")
    display_version = "v" + ".".join(version_text[:2]) if len(version_text) >= 2 else "v1.0"
    HTML = HTML.replace(b'<span class="app-version">v1.0</span>',
                        ('<span class="app-version">' + display_version + '</span>').encode("ascii"))
DEFAULTS = json.loads(re.search(rb'<script id="bounty-defaults" type="application/json">(.*?)</script>', HTML, re.S).group(1))
RULES = json.loads(re.search(rb'<script id="bounty-rules" type="application/json">(.*?)</script>', HTML, re.S).group(1))
LIMITS = {key: rule["max"] for key, rule in RULES.items()}


def build_level_table(rule):
    value = round(rule['base'] * 100)
    values, spent = [value / 100], [0]
    total = 0
    for band in rule['bands']:
        end, step = round(band['until'] * 100), round(band['step'] * 100)
        cost = band['initialCost']
        while value < end:
            value = min(end, value + step)
            values.append(value / 100)
            total += cost
            spent.append(total)
            cost += band['costStep']
    return {'values': values, 'spent': spent}


LEVEL_TABLES = {key: build_level_table(rule) for key, rule in RULES.items()}
LEVEL_VALUES = {key: table['values'] for key, table in LEVEL_TABLES.items()}
SPENT_BY_LEVEL = {key: table['spent'] for key, table in LEVEL_TABLES.items()}
SLOT_COSTS = json.loads(re.search(rb'<script id="bounty-slot-costs" type="application/json">(.*?)</script>', HTML, re.S).group(1))
CREATURES = {c['name'].casefold(): c for c in json.loads(re.search(rb'<script id="bounty-creatures" type="application/json">(.*?)</script>', HTML, re.S).group(1))}
EMBEDDED_SPRITES = json.loads(re.search(rb'<script id="bounty-sprites" type="application/json">(.*?)</script>', HTML, re.S).group(1))
MAJOR_CHARMS = {
    'Carnage', 'Curse', 'Divine Wrath', 'Dodge', 'Enflame', 'Freeze', 'Low Blow',
    'Overpower', 'Overflux', 'Parry', 'Poison', 'Savage Blow', 'Wound', 'Zap',
}
MINOR_CHARMS = {
    'Adrenaline Burst', 'Bless', 'Cleanse', 'Cripple', 'Fatal Hold', 'Gut',
    'Numb', 'Scavenge', 'Vampiric Embrace', 'Void Inversion', "Void's Call",
}
CHARM_ICON_URLS = {
    'Carnage': 'https://www.tibiawiki.com.br/images/3/30/Carnage_Icon.gif',
    'Curse': 'https://www.tibiawiki.com.br/images/e/e3/Curse_Icon.gif',
    'Divine Wrath': 'https://www.tibiawiki.com.br/images/c/cc/Divine_Wrath_Icon.gif',
    'Dodge': 'https://www.tibiawiki.com.br/images/2/25/Dodge_Icon.gif',
    'Enflame': 'https://www.tibiawiki.com.br/images/7/74/Enflame_Icon.gif',
    'Freeze': 'https://www.tibiawiki.com.br/images/7/72/Freeze_Icon.gif',
    'Low Blow': 'https://www.tibiawiki.com.br/images/8/8c/Low_Blow_Icon.gif',
    'Overpower': 'https://www.tibiawiki.com.br/images/2/2b/Overpower_Icon.gif',
    'Overflux': 'https://www.tibiawiki.com.br/images/2/20/Overflux_Icon.gif',
    'Parry': 'https://www.tibiawiki.com.br/images/a/a8/Parry_Icon.gif',
    'Poison': 'https://www.tibiawiki.com.br/images/5/59/Poison_Icon.gif',
    'Savage Blow': 'https://www.tibiawiki.com.br/images/e/e6/Savage_Blow_Icon.gif',
    'Wound': 'https://www.tibiawiki.com.br/images/d/d9/Wound_Icon.gif',
    'Zap': 'https://www.tibiawiki.com.br/images/2/2f/Zap_Icon.gif',
    'Adrenaline Burst': 'https://www.tibiawiki.com.br/images/1/1d/Adrenaline_Burst_Icon.gif',
    'Bless': 'https://www.tibiawiki.com.br/images/6/6c/Bless_Icon.gif',
    'Cleanse': 'https://www.tibiawiki.com.br/images/9/92/Cleanse_Icon.gif',
    'Cripple': 'https://www.tibiawiki.com.br/images/9/9c/Cripple_Icon.gif',
    'Fatal Hold': 'https://www.tibiawiki.com.br/images/b/b8/Fatal_Hold_Icon.gif',
    'Gut': 'https://www.tibiawiki.com.br/images/f/f0/Gut_Icon.gif',
    'Numb': 'https://www.tibiawiki.com.br/images/0/03/Numb_Icon.gif',
    'Scavenge': 'https://www.tibiawiki.com.br/images/5/5f/Scavenge_Icon.gif',
    'Vampiric Embrace': 'https://www.tibiawiki.com.br/images/4/41/Vampiric_Embrace_Icon.gif',
    'Void Inversion': 'https://www.tibiawiki.com.br/images/7/79/Void_Inversion_Icon.gif',
    "Void's Call": 'https://www.tibiawiki.com.br/images/c/c6/Void%27s_Call_Icon.gif',
}
BOUNTY_DIFFICULTIES = {'', 'Beginner', 'Adept', 'Expert', 'Master'}
EDITABLE = set(DEFAULTS) - {"schemaVersion", "revision", "updatedAt", "points", "slot0"}
STATE_PATH = ROOT / "dados" / "bounty-state.json"
CREATURE_INFO_CACHE_PATH = ROOT / "dados" / "creature-info-cache.json"
LOCK = threading.RLock()
STATE = copy.deepcopy(DEFAULTS)
CREATURE_INFO_LOCK = threading.RLock()
CREATURE_INFO_CACHE = {}
CREATURE_INFO_CACHE_LOADED = False


def finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or (isinstance(value, float) and not math.isfinite(value)):
        raise ValueError("Informe um número válido.")
    return value


def number(value, maximum):
    return round(max(0, min(maximum, finite_number(value))), 2)


def attribute_level(key, value):
    rule = RULES[key]
    value = max(rule['base'], min(rule['max'], finite_number(value)))
    values = LEVEL_VALUES[key]
    upper = bisect.bisect_left(values, value)
    if upper == 0:
        return 0
    if upper >= len(values):
        return len(values) - 1
    return upper - 1 if value - values[upper - 1] < values[upper] - value - 1e-9 else upper


def attribute_value(key, value):
    return LEVEL_VALUES[key][attribute_level(key, value)]


def derive_points(state):
    state['slot0'] = True
    available = True
    for index in range(1, 5):
        available = available and bool(state.get('slot' + str(index), False))
        state['slot' + str(index)] = available
    total = 0
    for key in RULES:
        level = attribute_level(key, state[key])
        state[key] = LEVEL_VALUES[key][level]
        total += SPENT_BY_LEVEL[key][level]
    state['points'] = total + sum(cost for i, cost in enumerate(SLOT_COSTS) if state.get('slot' + str(i), False))
    state['schemaVersion'] = DEFAULTS['schemaVersion']
    return state
def apply_patch(state, patch):
    if not isinstance(patch, dict):
        raise ValueError("Formato de alteração inválido.")
    next_state = copy.deepcopy(state)
    for key, value in patch.items():
        if key not in EDITABLE:
            raise ValueError("Campo inválido: " + str(key))
        if key in RULES:
            next_state[key] = attribute_value(key, value)
        elif key in LIMITS:
            next_state[key] = number(value, LIMITS[key])
        elif key == "theme":
            if value not in ("emerald", "sapphire", "ruby"):
                raise ValueError("Tema inválido.")
            next_state[key] = value
        elif key == 'difficulty':
            if not isinstance(value, str) or value not in BOUNTY_DIFFICULTIES:
                raise ValueError('Dificuldade da bounty inválida.')
            next_state[key] = value
        elif key.startswith('charm'):
            if not isinstance(value, str) or value not in (MAJOR_CHARMS | {''}):
                raise ValueError('Charm inválido.')
            next_state[key] = value
        elif key.startswith('minorCharm'):
            if not isinstance(value, str) or value not in (MINOR_CHARMS | {''}):
                raise ValueError('Minor Charm inválido.')
            next_state[key] = value
        elif isinstance(DEFAULTS[key], bool):
            if not isinstance(value, bool):
                raise ValueError("Opção inválida.")
            next_state[key] = value
        elif key.startswith('monster'):
            if not isinstance(value, str) or (value.strip() and value.strip().casefold() not in CREATURES):
                raise ValueError('Selecione um monstro do catálogo.')
            next_state[key] = CREATURES[value.strip().casefold()]['name'] if value.strip() else ''
        else:
            if not isinstance(value, str):
                raise ValueError("Texto inválido.")
            next_state[key] = value[:32 if key in ("title", "characterName") else 44]
    for index in range(1, 5):
        if patch.get('slot' + str(index)) is True and not all(next_state.get('slot' + str(previous), False) for previous in range(1, index)):
            raise ValueError('Adquira os slots anteriores primeiro.')
    return derive_points(next_state)


def load_state():
    global STATE
    if not STATE_PATH.exists():
        return
    try:
        raw = json.loads(STATE_PATH.read_text(encoding="utf-8-sig"))
        if not isinstance(raw, dict):
            raise ValueError("invalid state")
        next_state = copy.deepcopy(DEFAULTS)
        for key in sorted(EDITABLE):
            if key in raw:
                try:
                    next_state = apply_patch(next_state, {key: raw[key]})
                except ValueError:
                    pass
        revision = raw.get("revision", 0)
        next_state["revision"] = revision if type(revision) is int and 0 <= revision < 2**53 else 0
        next_state["updatedAt"] = raw.get("updatedAt") if isinstance(raw.get("updatedAt"), str) else None
        STATE = derive_points(next_state)
    except (ValueError, OSError):
        print("Aviso: o arquivo de valores não pôde ser lido. Usando valores iniciais.")


def persist(state):
    STATE_PATH.parent.mkdir(exist_ok=True)
    temporary = STATE_PATH.with_suffix(".tmp")
    with temporary.open("w", encoding="utf-8") as output:
        json.dump(state, output, ensure_ascii=False, allow_nan=False, indent=2)
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, STATE_PATH)


# GIFs are fetched only from the embedded, fixed Tibia Wiki catalog.
SPRITE_LOCK = threading.Lock()
JOBS_LOCK = threading.RLock()
JOBS = {}


def sprite_bytes(name):
    creature = CREATURES.get(name.casefold())
    if not creature:
        raise ValueError('Monstro não encontrado no catálogo.')
    canonical = creature['name']
    embedded = EMBEDDED_SPRITES.get(canonical)
    if embedded:
        return base64.b64decode(embedded.split(',', 1)[1])
    cache = ROOT / 'dados' / 'sprites'
    path = cache / (hashlib.sha256(canonical.encode('utf-8')).hexdigest()[:24] + '.gif')
    with SPRITE_LOCK:
        if path.exists():
            content = path.read_bytes()
        else:
            url = creature['url']
            if not url.startswith('https://www.tibiawiki.com.br/images/'):
                raise ValueError('Origem de imagem inválida.')
            request = urllib.request.Request(url, headers={'User-Agent': 'BountyStudio/1.0 (local overlay)'})
            with urllib.request.urlopen(request, timeout=12) as response:
                content = response.read(2097153)
            if not content.startswith((b'GIF87a', b'GIF89a')) or len(content) > 2097152:
                raise ValueError('GIF inválido.')
            cache.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    if not content.startswith((b'GIF87a', b'GIF89a')) or len(content) > 2097152:
        raise ValueError('GIF inválido.')
    return content


def charm_icon_bytes(name):
    url = CHARM_ICON_URLS.get(name)
    if not url:
        raise ValueError('Charm não encontrado no catálogo.')
    cache = ROOT / 'dados' / 'charm-icons'
    path = cache / (hashlib.sha256(name.encode('utf-8')).hexdigest()[:24] + '.gif')
    with SPRITE_LOCK:
        if path.exists():
            content = path.read_bytes()
        else:
            request = urllib.request.Request(url, headers={'User-Agent': 'BountyStudio/1.0 (local overlay; charm icons from Tibia Wiki)'})
            with urllib.request.urlopen(request, timeout=12) as response:
                content = response.read(65537)
            if not content.startswith((b'GIF87a', b'GIF89a')) or len(content) > 65536:
                raise ValueError('Ícone de charm inválido.')
            cache.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    if not content.startswith((b'GIF87a', b'GIF89a')) or len(content) > 65536:
        raise ValueError('Ícone de charm inválido.')
    return content


def creature_info_number(wikitext, key):
    match = re.search(r'(?im)^\s*\|\s*' + re.escape(key) + r'\s*=\s*([^\r\n]*)', wikitext)
    if not match:
        return None
    digits = ''.join(re.findall(r'\d', match.group(1).split('|', 1)[0]))
    return int(digits) if digits else None


def persist_creature_info_cache():
    temporary = CREATURE_INFO_CACHE_PATH.with_suffix('.tmp')
    with temporary.open('w', encoding='utf-8') as output:
        json.dump(CREATURE_INFO_CACHE, output, ensure_ascii=False, allow_nan=False, indent=2)
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, CREATURE_INFO_CACHE_PATH)


def load_creature_info_cache():
    global CREATURE_INFO_CACHE, CREATURE_INFO_CACHE_LOADED
    try:
        cached = json.loads(CREATURE_INFO_CACHE_PATH.read_text(encoding='utf-8'))
        if isinstance(cached, dict):
            CREATURE_INFO_CACHE = cached
    except (OSError, ValueError):
        pass
    CREATURE_INFO_CACHE_LOADED = True


def creature_info(name):
    if not CREATURE_INFO_CACHE_LOADED:
        with CREATURE_INFO_LOCK:
            if not CREATURE_INFO_CACHE_LOADED:
                load_creature_info_cache()
    creature = CREATURES.get(name.casefold())
    if not creature:
        raise ValueError('Monstro não encontrado no catálogo.')
    canonical = creature['name']
    now = time.time()
    with CREATURE_INFO_LOCK:
        cached = CREATURE_INFO_CACHE.get(canonical)
        if isinstance(cached, dict) and now - cached.get('cachedAt', 0) < 30 * 86400:
            result = {key: cached.get(key) for key in ('name', 'hp', 'xp', 'source')}
            result['available'] = True
            return result

    query = urllib.parse.urlencode({
        'action': 'parse', 'page': canonical, 'prop': 'wikitext', 'format': 'json',
    })
    request = urllib.request.Request(
        'https://www.tibiawiki.com.br/api.php?' + query,
        headers={'User-Agent': 'BountyStudio/1.0 (local overlay; creature stats from Tibia Wiki)'},
    )
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            payload = json.loads(response.read(2 * 1024 * 1024).decode('utf-8'))
    except (OSError, ValueError):
        with CREATURE_INFO_LOCK:
            cached = CREATURE_INFO_CACHE.get(canonical)
            if isinstance(cached, dict):
                result = {key: cached.get(key) for key in ('name', 'hp', 'xp', 'source')}
                result['available'] = True
                result['stale'] = True
                return result
        return {
            'name': canonical, 'hp': None, 'xp': None,
            'source': 'https://www.tibiawiki.com.br/wiki/' + urllib.parse.quote(canonical.replace(' ', '_')),
            'available': False,
        }
    parsed = payload.get('parse', {})
    wikitext = parsed.get('wikitext', '')
    if isinstance(wikitext, dict):
        wikitext = wikitext.get('*', '')
    if not isinstance(wikitext, str):
        wikitext = ''
    info = {
        'name': canonical,
        'hp': creature_info_number(wikitext, 'hp'),
        'xp': creature_info_number(wikitext, 'exp'),
        'source': 'https://www.tibiawiki.com.br/wiki/' + urllib.parse.quote(canonical.replace(' ', '_')),
        'available': True,
    }
    if info['hp'] is None and info['xp'] is None:
        info['available'] = False
        return info
    with CREATURE_INFO_LOCK:
        CREATURE_INFO_CACHE[canonical] = dict(info, cachedAt=now)
        try:
            persist_creature_info_cache()
        except OSError:
            pass
    return info


def validate_bundled_encoder(binary):
    try:
        manifest = json.loads((TOOLS_ROOT / 'ffmpeg-manifest.json').read_text(encoding='utf-8'))
        expected_size, expected_hash = manifest['size'], manifest['sha256']
    except (OSError, ValueError, KeyError, TypeError):
        raise ValueError('Os arquivos do codificador estão incompletos. Extraia o pacote atualizado inteiro, incluindo a pasta tools.')
    if binary.stat().st_size != expected_size:
        raise ValueError('O codificador de vídeo está incompleto. Baixe o pacote atualizado e substitua a pasta tools inteira.')
    digest = hashlib.sha256()
    with binary.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    if digest.hexdigest() != expected_hash:
        raise ValueError('O arquivo do codificador foi alterado ou corrompido. Substitua a pasta tools pelo conteúdo do pacote atualizado.')


def encoder_launch_error(error):
    code = getattr(error, 'winerror', None)
    if code in (193, 216):
        return 'O Windows não conseguiu executar o codificador. Este pacote requer Windows de 64 bits.'
    if code == 5 or getattr(error, 'errno', None) == 13:
        return 'O sistema negou a execução do codificador. Verifique a permissão do executável FFmpeg incluído.'
    if code == 2 or isinstance(error, FileNotFoundError):
        return 'O codificador de vídeo não foi encontrado. Extraia a pasta tools do pacote atualizado.'
    return 'Não foi possível abrir o codificador de vídeo.' + (' Código do Windows: ' + str(code) + '.' if code else ' Reinicie o painel e tente novamente.')


def check_encoder(binary):
    try:
        result = subprocess.run([binary, '-version'], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                stderr=subprocess.PIPE, timeout=8,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    except OSError as error:
        raise ValueError(encoder_launch_error(error)) from error
    except subprocess.TimeoutExpired:
        raise ValueError('O codificador não respondeu. Reinicie o painel e tente novamente.')
    if result.returncode != 0:
        raise ValueError('O codificador não iniciou corretamente. Reinicie o painel e verifique a pasta tools do pacote atualizado.')
    return binary


def ffmpeg_path():
    bundled = TOOLS_ROOT / 'ffmpeg.exe'
    if os.name == 'nt' and bundled.is_file():
        validate_bundled_encoder(bundled)
        return check_encoder(str(bundled))
    binary = shutil.which('ffmpeg')
    if not binary:
        raise ValueError('FFmpeg não encontrado. No Windows, extraia o pacote completo; no macOS/Linux, instale o FFmpeg para exportar.')
    return check_encoder(binary)


def remove_job(job_id):
    with JOBS_LOCK:
        job = JOBS.pop(job_id, None)
    if not job:
        return
    process = job.get('process')
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    if job.get('log'):
        job['log'].close()
    shutil.rmtree(job['directory'], ignore_errors=True)


def job_for(job_id):
    if not isinstance(job_id, str) or not re.fullmatch('[0-9a-f]{32}', job_id):
        raise ValueError('Exportação inválida.')
    job = JOBS.get(job_id)
    if job is None:
        raise ValueError('Exportação não encontrada. Tente novamente.')
    job['touched'] = time.monotonic()
    return job


def video_command(binary, directory):
    return [binary, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '30',
            '-i', str(directory / '%03d.png'), '-frames:v', '270', '-an',
            '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuva420p', '-b:v', '0', '-lossless', '1',
            '-deadline', 'good', '-cpu-used', '4', '-threads', '2',
            '-auto-alt-ref', '0', str(directory / 'overlay.webm')]


def export_status(job):
    process = job.get('process')
    if job['status'] == 'encoding' and process is not None:
        code = process.poll()
        if code is not None:
            if job.get('log'):
                job['log'].close()
                job['log'] = None
            output = job['directory'] / 'overlay.webm'
            job['status'] = 'ready' if code == 0 and output.exists() and output.stat().st_size > 0 else 'error'
    return {'status': job['status'], 'error': 'Não foi possível codificar o vídeo. Extraia o pacote completo e tente novamente.' if job['status'] == 'error' else None}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass

    def reply(self, status, body, content_type="application/json; charset=utf-8"):
        if not isinstance(body, bytes):
            body = json.dumps(body, ensure_ascii=False, allow_nan=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def allowed(self):
        hosts = {"127.0.0.1:" + str(self.server.server_port), "localhost:" + str(self.server.server_port)}
        if self.headers.get("Host", "") not in hosts:
            self.reply(403, {"error": "Endereço local inválido."})
            return False
        origin = self.headers.get("Origin")
        if origin and origin != "http://" + self.headers.get("Host", ""):
            self.reply(403, {"error": "Origem inválida."})
            return False
        return True

    def do_assets_GET(self, path, query):
        try:
            if path == '/api/sprite':
                self.reply(200, sprite_bytes(query.get('name', [''])[0]), 'image/gif')
                return
            if path == '/api/charm-icon':
                self.reply(200, charm_icon_bytes(query.get('name', [''])[0]), 'image/gif')
                return
            if path == '/api/creature-info':
                self.reply(200, creature_info(query.get('name', [''])[0]))
                return
            job_id = query.get('id', [''])[0]
            with JOBS_LOCK:
                job = job_for(job_id)
                status = export_status(job)
                if path == '/api/export/status':
                    self.reply(200, status)
                elif path == '/api/export/video' and status['status'] == 'ready':
                    self.reply(200, (job['directory'] / 'overlay.webm').read_bytes(), 'video/webm')
                else:
                    self.reply(400, {'error': 'O vídeo ainda não está pronto.'})
        except (ValueError, OSError) as error:
            self.reply(400, {'error': str(error) if isinstance(error, ValueError) else 'GIF indisponível. Verifique a internet e tente recarregar.'})

    def do_export_POST(self, path, query):
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if path == '/api/export/frame':
                if self.headers.get('Content-Type', '').split(';')[0] != 'image/png' or not 33 <= size <= 2097152:
                    raise ValueError('Quadro de vídeo inválido.')
                content = self.rfile.read(size)
                if len(content) != size or content[:8] != b'\x89PNG\r\n\x1a\n' or content[12:16] != b'IHDR' or struct.unpack('>II', content[16:24]) != (1200, 360):
                    raise ValueError('O quadro precisa ser um PNG de 1200 × 360.')
                index = int(query.get('index', ['-1'])[0])
                if not 0 <= index < 270:
                    raise ValueError('Índice de quadro inválido.')
                with JOBS_LOCK:
                    job = job_for(query.get('id', [''])[0])
                    if job['status'] != 'collecting':
                        raise ValueError('Esta exportação não está recebendo quadros.')
                    (job['directory'] / ('%03d.png' % index)).write_bytes(content)
                    job['frames'].add(index)
                self.reply(200, {'ok': True})
                return
            if self.headers.get('Content-Type', '').split(';')[0] != 'application/json' or not 0 < size <= 1024:
                raise ValueError('Requisição de exportação inválida.')
            payload = json.loads(self.rfile.read(size))
            if not isinstance(payload, dict):
                raise ValueError('Requisição de exportação inválida.')
            if path == '/api/export/start':
                if payload.get('fps') != 30 or payload.get('frameCount') != 270:
                    raise ValueError('O vídeo precisa ter 9 segundos, a 30 quadros por segundo.')
                binary = ffmpeg_path()
                with JOBS_LOCK:
                    for old_id, old in list(JOBS.items()):
                        if time.monotonic() - old['touched'] > 600:
                            remove_job(old_id)
                    if len(JOBS) >= 3:
                        raise ValueError('Há outra exportação em andamento. Aguarde ou cancele antes de tentar novamente.')
                    job_id = uuid.uuid4().hex
                    JOBS[job_id] = {'directory': Path(tempfile.mkdtemp(prefix='bounty-video-')), 'frames': set(), 'status': 'collecting', 'binary': binary, 'touched': time.monotonic()}
                self.reply(200, {'id': job_id})
                return
            job_id = query.get('id', [''])[0]
            with JOBS_LOCK:
                job = job_for(job_id)
                if path == '/api/export/finish':
                    if job['status'] != 'collecting' or job['frames'] != set(range(270)):
                        raise ValueError('A exportação precisa de todos os 270 quadros antes de finalizar.')
                    job['log'] = (job['directory'] / 'ffmpeg.log').open('wb')
                    try:
                        job['process'] = subprocess.Popen(video_command(job['binary'], job['directory']), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=job['log'], creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                    except OSError as error:
                        job['log'].close()
                        job['log'] = None
                        raise ValueError(encoder_launch_error(error)) from error
                    job['status'] = 'encoding'
                    self.reply(200, {'ok': True})
                elif path == '/api/export/cancel':
                    remove_job(job_id)
                    self.reply(200, {'ok': True})
                else:
                    self.reply(404, {'error': 'Requisição inválida.'})
        except (ValueError, UnicodeError, OSError) as error:
            self.reply(400, {'error': str(error) if isinstance(error, ValueError) else 'Não foi possível salvar os quadros do vídeo.'})

    def do_GET(self):
        if not self.allowed():
            return
        path = urllib.parse.urlsplit(self.path).path
        if path in ('/api/sprite', '/api/charm-icon', '/api/creature-info', '/api/export/status', '/api/export/video'):
            self.do_assets_GET(path, urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query))
        elif path == "/api/health":
            self.reply(200, {"kind": "bounty-studio", "version": DEFAULTS['schemaVersion']})
        elif path == "/api/state":
            with LOCK:
                self.reply(200, STATE)
        elif path in ("/overlay", "/painel", "/251vqzs.html"):
            self.reply(200, HTML, "text/html; charset=utf-8")
        elif path in ("/", "/painel.html"):
            self.send_response(302)
            self.send_header("Location", "/painel")
            self.send_header("Content-Length", "0")
            self.send_header("Connection", "close")
            self.end_headers()
            self.close_connection = True
        elif path == "/favicon.ico":
            self.reply(204, b"")
        else:
            self.reply(404, {"error": "Página não encontrada."})

    def do_POST(self):
        global STATE
        if not self.allowed():
            return
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path.startswith('/api/export/'):
            self.do_export_POST(parsed.path, urllib.parse.parse_qs(parsed.query))
            return
        if urllib.parse.urlsplit(self.path).path != "/api/state":
            self.reply(404, {"error": "Página não encontrada."})
            return
        if self.headers.get("Content-Type", "").split(";")[0].strip() != "application/json":
            self.reply(415, {"error": "Envie alterações em JSON."})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 16384:
                raise ValueError("Tamanho de alteração inválido.")
            payload = json.loads(self.rfile.read(size), parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Número inválido.")))
            if not isinstance(payload, dict):
                raise ValueError("Formato de alteração inválido.")
            with LOCK:
                next_state = apply_patch(STATE, payload.get("patch", {}))
                if "adjust" in payload:
                    adjust = payload["adjust"]
                    if not isinstance(adjust, dict) or not isinstance(adjust.get("key"), str) or adjust.get("key") not in LIMITS:
                        raise ValueError("Ajuste inválido.")
                    key = adjust['key']
                    if 'levels' in adjust:
                        levels = adjust['levels']
                        if type(levels) is not int or levels not in (-1, 1):
                            raise ValueError('Adicione ou remova um nível por vez.')
                        current = attribute_level(key, next_state[key])
                        values = LEVEL_VALUES[key]
                        next_state[key] = values[max(0, min(len(values) - 1, current + levels))]
                    else:
                        # Compatibility with an earlier control window.
                        delta = adjust.get('delta')
                        if isinstance(delta, bool) or not isinstance(delta, (int, float)) or (isinstance(delta, float) and not math.isfinite(delta)) or abs(delta) > 1e9:
                            raise ValueError('Ajuste inválido.')
                        next_state[key] = attribute_value(key, next_state[key] + delta)
                next_state = derive_points(next_state)
                next_state["revision"] = STATE["revision"] + 1
                next_state["updatedAt"] = dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
                persist(next_state)
                STATE = next_state
                self.reply(200, STATE)
        except (ValueError, UnicodeError) as error:
            self.reply(400, {"error": str(error)})
        except OSError:
            self.reply(500, {"error": "Não foi possível salvar. Extraia o pacote para uma pasta com permissão de escrita."})


def main():
    parser = argparse.ArgumentParser(description="Bounty Studio · servidor local")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    address = "http://127.0.0.1:" + str(args.port)
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    except OSError:
        try:
            with urllib.request.urlopen(address + "/api/health", timeout=1) as response:
                existing = json.load(response)
            if existing.get("kind") == "bounty-studio":
                print("O Bounty Studio já está aberto.")
                if not args.no_browser:
                    webbrowser.open(address + "/painel")
                return 0
        except (OSError, ValueError):
            pass
        print("Não foi possível abrir a porta " + str(args.port) + ". Feche o programa que está usando essa porta e tente novamente.")
        return 1
    load_state()
    with LOCK:
        STATE['overlayUrlEnabled'] = False
    server.daemon_threads = True
    print("\nBOUNTY STUDIO\n")
    print("Painel:  " + address + "/painel")
    print("Overlay: " + address + "/overlay")
    print("\nDeixe esta janela aberta durante a live. Ctrl+C encerra.\n")
    if not args.no_browser:
        threading.Timer(.4, lambda: webbrowser.open(address + "/painel")).start()
    try:
        server.serve_forever(poll_interval=.25)
    except KeyboardInterrupt:
        print("\nBounty Studio encerrado.")
    finally:
        server.server_close()
        for job_id in list(JOBS):
            remove_job(job_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
