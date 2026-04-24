# Felicita - Plataforma Contable SaaS

Plataforma multi-tenant para contadores que gestionan multiples empresas.

## Inicio rapido

### 1. Base de datos (PostgreSQL)
`sql
CREATE DATABASE felicita_db;
CREATE USER felicita_user WITH PASSWORD 'felicita2026';
GRANT ALL PRIVILEGES ON DATABASE felicita_db TO felicita_user;
`

### 2. Backend
`powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
`

### 3. Datos de prueba
`powershell
python seed.py
`

### 4. Frontend (nueva terminal)
`powershell
cd frontend
npm install
npm run dev
`

## Acceso
- Backend API: http://localhost:8000/docs
- Frontend: http://localhost:5173
- Admin: admin@felicita.pe / admin123
- Contador: ana.perez@felicita.pe / contador123
