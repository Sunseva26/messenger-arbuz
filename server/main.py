from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import json
import os
import uuid
from datetime import datetime
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

# Папки для данных и файлов
DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), 'uploads')
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(UPLOAD_DIR, exist_ok=True)

MESSAGES_FILE = os.path.join(DATA_DIR, 'messages.json')
GROUPS_FILE = os.path.join(DATA_DIR, 'groups.json')
CHANNELS_FILE = os.path.join(DATA_DIR, 'channels.json')
USERS_FILE = os.path.join(DATA_DIR, 'users.json')

# === Вспомогательные функции ===

def read_json(filepath):
    if not os.path.exists(filepath):
        return []
    with open(filepath, 'r', encoding='utf-8') as f:
        try:
            return json.load(f)
        except:
            return []

def write_json(filepath, data):
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# === Пользователи ===

@app.route('/users', methods=['GET'])
def get_users():
    users = read_json(USERS_FILE)
    return jsonify(users)

@app.route('/users', methods=['POST'])
def create_user():
    data = request.json
    if not data or not data.get('username'):
        return jsonify({'error': 'Имя пользователя обязательно'}), 400
    
    users = read_json(USERS_FILE)
    # Проверяем уникальность
    if any(u['username'] == data['username'] for u in users):
        return jsonify({'error': 'Пользователь уже существует'}), 400
    
    user = {
        'id': str(uuid.uuid4()),
        'username': data['username'],
        'avatar_url': data.get('avatar_url', ''),
        'bio': data.get('bio', ''),
        'is_admin': data.get('is_admin', False),
        'created_at': datetime.now().isoformat()
    }
    users.append(user)
    write_json(USERS_FILE, users)
    return jsonify(user), 201

# === Группы ===

@app.route('/groups', methods=['GET'])
def get_groups():
    groups = read_json(GROUPS_FILE)
    return jsonify(groups)

@app.route('/groups', methods=['POST'])
def create_group():
    data = request.json
    if not data or not data.get('name'):
        return jsonify({'error': 'Название обязательно'}), 400
    
    groups = read_json(GROUPS_FILE)
    group = {
        'id': str(uuid.uuid4()),
        'name': data['name'],
        'description': data.get('description', ''),
        'created_by': data.get('created_by', ''),
        'members': data.get('members', []),
        'created_at': datetime.now().isoformat()
    }
    groups.append(group)
    write_json(GROUPS_FILE, groups)
    return jsonify(group), 201

# === КАНАЛЫ ===

@app.route('/channels', methods=['GET'])
def get_channels():
    channels = read_json(CHANNELS_FILE)
    return jsonify(channels)

@app.route('/channels', methods=['POST'])
def create_channel():
    data = request.json
    if not data or not data.get('name'):
        return jsonify({'error': 'Название канала обязательно'}), 400
    
    channels = read_json(CHANNELS_FILE)
    channel = {
        'id': str(uuid.uuid4()),
        'name': data['name'],
        'description': data.get('description', ''),
        'created_by': data.get('created_by', ''),
        'subscribers': data.get('subscribers', []),
        'created_at': datetime.now().isoformat()
    }
    channels.append(channel)
    write_json(CHANNELS_FILE, channels)
    return jsonify(channel), 201

@app.route('/channels/<channel_id>/subscribe', methods=['POST'])
def subscribe_channel(channel_id):
    data = request.json
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({'error': 'user_id обязателен'}), 400
    
    channels = read_json(CHANNELS_FILE)
    for ch in channels:
        if ch['id'] == channel_id:
            if user_id not in ch['subscribers']:
                ch['subscribers'].append(user_id)
                write_json(CHANNELS_FILE, channels)
            return jsonify(ch)
    return jsonify({'error': 'Канал не найден'}), 404

# === Сообщения (для групп, каналов и личных чатов) ===

@app.route('/messages/<chat_type>/<chat_id>', methods=['GET'])
def get_messages(chat_type, chat_id):
    """
    chat_type может быть: group, channel, private
    """
    messages = read_json(MESSAGES_FILE)
    chat_messages = [m for m in messages if m['chat_type'] == chat_type and m['chat_id'] == chat_id]
    chat_messages.sort(key=lambda x: x['created_at'])
    return jsonify(chat_messages)

@app.route('/messages', methods=['POST'])
def send_message():
    file = request.files.get('file')
    username = request.form.get('username')
    text = request.form.get('text', '')
    chat_type = request.form.get('chat_type')  # group, channel, private
    chat_id = request.form.get('chat_id')
    user_id = request.form.get('user_id', '')

    if not username or not chat_id or not chat_type:
        return jsonify({'error': 'Заполните обязательные поля'}), 400

    # Проверка прав для каналов
    if chat_type == 'channel':
        channels = read_json(CHANNELS_FILE)
        channel = next((ch for ch in channels if ch['id'] == chat_id), None)
        if channel and channel.get('created_by') and channel['created_by'] != user_id:
            return jsonify({'error': 'Только создатель канала может писать сообщения'}), 403

    file_url = None
    file_type = None

    if file:
        filename = secure_filename(file.filename)
        unique_name = f"{uuid.uuid4()}_{filename}"
        filepath = os.path.join(UPLOAD_DIR, unique_name)
        file.save(filepath)
        file_url = f"/uploads/{unique_name}"
        ext = filename.lower()
        if ext.endswith(('.jpg', '.jpeg', '.png', '.gif', '.webp')):
            file_type = 'image'
        elif ext.endswith(('.mp4', '.mov', '.avi', '.webm')):
            file_type = 'video'
        else:
            file_type = 'file'

    messages = read_json(MESSAGES_FILE)
    message = {
        'id': str(uuid.uuid4()),
        'chat_type': chat_type,
        'chat_id': chat_id,
        'username': username,
        'user_id': user_id,
        'text': text,
        'file_url': file_url,
        'file_type': file_type,
        'created_at': datetime.now().isoformat()
    }
    messages.append(message)
    write_json(MESSAGES_FILE, messages)
    return jsonify(message), 201

# === Получение файлов ===

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(UPLOAD_DIR, filename)

# === Статистика ===

@app.route('/stats', methods=['GET'])
def get_stats():
    return jsonify({
        'users': len(read_json(USERS_FILE)),
        'groups': len(read_json(GROUPS_FILE)),
        'channels': len(read_json(CHANNELS_FILE)),
        'messages': len(read_json(MESSAGES_FILE))
    })

# === Запуск ===

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
