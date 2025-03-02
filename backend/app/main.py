from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta
from typing import Optional
from prisma import Prisma
from pydantic import BaseModel
from . import models, security
from .database import engine, get_db
from sqlalchemy.orm import Session
import logging
import requests

SECRET_KEY = "ef0fb1fdd12e9a317d941c1824d1a46a65bfbdaa980e28cbe6e8298028bef64a"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

app = FastAPI()
prisma = Prisma()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

class Token(BaseModel):
    access_token: str
    token_type: str

class UserCreate(BaseModel):
    email: str
    name: str
    password: Optional[str] = None
    location: Optional[str] = None
    avatarUrl: Optional[str] = None

@app.on_event("startup")
async def startup():
    await prisma.connect()

@app.on_event("shutdown")
async def shutdown():
    await prisma.disconnect()

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

@app.post("/users/", response_model=dict)
async def create_user(user: UserCreate):
    try:
        hashed_password = get_password_hash(user.password) if user.password else None
        db_user = await prisma.user.create({
            'data': {
                'email': user.email,
                'name': user.name,
                'passwordHash': hashed_password,
                'location': user.location,
                'avatarUrl': user.avatarUrl
            }
        })
        return {"message": "User created successfully", "id": db_user.id}
    except Exception as e:
        logging.error(f"Error creating user: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@app.post("/token", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = await prisma.user.find_first(where={'email': form_data.username})
    if not user or not verify_password(form_data.password, user.passwordHash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me")
async def read_users_me(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    
    user = await prisma.user.find_first(where={'email': email})
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "location": user.location,
        "avatarUrl": user.avatarUrl
    }

models.Base.metadata.create_all(bind=engine)

@app.post("/register")
async def register_user(user: UserCreate, db: Session = Depends(get_db)):
    hashed_password = get_password_hash(user.password) if user.password else None
    db_user = models.User(email=user.email, password_hash=hashed_password, name=user.name, location=user.location, avatarUrl=user.avatarUrl)
    db.add(db_user)
    db.commit()
    return {"message": "User created successfully"}

@app.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    return {"access_token": create_access_token(user.email)}

@app.post("/login/google")
async def login_with_google(token: str):
    try:
        response = requests.get(f"https://oauth2.googleapis.com/tokeninfo?id_token={token}")
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Invalid Google token")
        user_info = response.json()
        email = user_info["email"]
        name = user_info["name"]
        avatar_url = user_info["picture"]

        user = await prisma.user.find_first(where={'email': email})
        if not user:
            user = await prisma.user.create({
                'data': {
                    'email': email,
                    'name': name,
                    'avatarUrl': avatar_url
                }
            })

        access_token = create_access_token(data={"sub": user.email})
        return {"access_token": access_token, "token_type": "bearer"}
    except Exception as e:
        logging.error(f"Error logging in with Google: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@app.post("/login/facebook")
async def login_with_facebook(token: str):
    try:
        response = requests.get(f"https://graph.facebook.com/me?access_token={token}&fields=id,name,email,picture")
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Invalid Facebook token")
        user_info = response.json()
        email = user_info["email"]
        name = user_info["name"]
        avatar_url = user_info["picture"]["data"]["url"]

        user = await prisma.user.find_first(where={'email': email})
        if not user:
            user = await prisma.user.create({
                'data': {
                    'email': email,
                    'name': name,
                    'avatarUrl': avatar_url
                }
            })

        access_token = create_access_token(data={"sub": user.email})
        return {"access_token": access_token, "token_type": "bearer"}
    except Exception as e:
        logging.error(f"Error logging in with Facebook: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@app.post("/login/apple")
async def login_with_apple(token: str):
    try:
        response = requests.post(
            "https://appleid.apple.com/auth/token",
            data={
                "client_id": "YOUR_APPLE_CLIENT_ID",
                "client_secret": "YOUR_APPLE_CLIENT_SECRET",
                "code": token,
                "grant_type": "authorization_code",
            },
        )
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Invalid Apple token")
        user_info = response.json()
        email = user_info["email"]
        name = user_info["name"]

        user = await prisma.user.find_first(where={'email': email})
        if not user:
            user = await prisma.user.create({
                'data': {
                    'email': email,
                    'name': name,
                }
            })

        access_token = create_access_token(data={"sub": user.email})
        return {"access_token": access_token, "token_type": "bearer"}
    except Exception as e:
        logging.error(f"Error logging in with Apple: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")