# awakenU Sentiment Analysis Platform

An AI-powered sentiment analysis platform with an interactive dashboard, user authentication, and payment integration.

## Features

- **Real-time Sentiment Analysis**: Analyze text and get instant sentiment scores
- **Interactive Dashboard**: Visualize sentiment trends with charts and graphs
- **User Authentication**: Secure sign-up and sign-in with Supabase
- **Payment Integration**: Upgrade plans to get more API calls
- **Analysis History**: Track all your previous analyses
- **Subscription Tiers**: Free, Pro, and Enterprise plans

## Tech Stack

- **Frontend**: Vanilla JavaScript, HTML5, CSS3, Chart.js
- **Backend**: FastAPI (Python)
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Build Tool**: Vite

## Setup Instructions

### 1. Install Dependencies

#### Python Dependencies
```bash
pip install -r requirements.txt
```

#### Node Dependencies
```bash
npm install
```

### 2. Environment Variables

The `.env` file already contains your Supabase credentials:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_SUPABASE_ANON_KEY`

### 3. Database Setup

The database schema has been automatically created with the following tables:
- `users`: User accounts and subscription info
- `sentiment_analyses`: All sentiment analysis records
- `payments`: Payment transaction history

### 4. Run the Application

#### Start the Backend (Terminal 1)
```bash
python3 -m uvicorn api.main:app --reload --port 8000
```

#### Start the Frontend (Terminal 2)
```bash
npm run dev
```

The application will be available at:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs

## Usage

1. **Sign Up**: Create a new account with email and password
2. **Analyze Text**: Enter text in the analyzer and get instant sentiment results
3. **View History**: See all your previous analyses
4. **Upgrade Plan**: Click "Upgrade Plan" to get more API calls
5. **Track Progress**: View sentiment trends in the interactive chart

## API Endpoints

- `GET /` - API welcome message
- `GET /api/health` - Health check
- `POST /api/analyze` - Analyze text sentiment
- `GET /api/analyses` - Get analysis history
- `GET /api/stats` - Get user statistics
- `DELETE /api/analyses/{id}` - Delete an analysis

## Subscription Tiers

- **Free**: 10 API calls
- **Pro**: 1,000 API calls/month - $9.99/month
- **Enterprise**: Unlimited API calls - $29.99/month

## Architecture

```
project/
├── api/
│   ├── main.py              # FastAPI application
│   ├── sentiment_engine.py  # Sentiment analysis logic
│   ├── database.py          # Supabase client & auth
│   └── __init__.py
├── index.html               # Main HTML file
├── app.js                   # Frontend JavaScript
├── vite.config.js          # Vite configuration
├── requirements.txt         # Python dependencies
├── package.json            # Node dependencies
└── .env                    # Environment variables
```

## Security Features

- Row Level Security (RLS) enabled on all tables
- User authentication with Supabase Auth
- Secure API endpoints with JWT tokens
- Users can only access their own data

## Development

The sentiment analysis engine uses a lexicon-based approach with:
- Positive and negative word dictionaries
- Intensifier detection (very, extremely, etc.)
- Negation handling (not, never, etc.)
- Confidence scoring

## Support

For issues or questions, please contact support.