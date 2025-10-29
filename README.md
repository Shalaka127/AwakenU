# Customer Support Analytics Platform

A comprehensive multi-tenant SaaS platform for ingesting, analyzing, and managing customer support emails with AI-powered sentiment analysis, urgency detection, and automated workflows.

## Features

### Core Functionality
- **Email Ingestion**: Automatically fetch and process emails from multiple providers
- **Sentiment Analysis**: AI-powered classification (positive/negative/neutral)
- **Urgency Detection**: Identify high-priority messages automatically
- **Intent Classification**: Categorize feedback (complaint/praise/question/request)
- **Multi-Tenant Architecture**: Secure isolation between client organizations
- **Real-time Dashboard**: Live analytics and feedback monitoring
- **Mark Satisfied**: One-click resolution with optional auto-reply
- **Export Data**: CSV/JSON exports with filtering (Pro feature)
- **Subscription Management**: Free, Pro, and Enterprise tiers

### Technical Features
- **SendGrid Webhook Integration**: Real-time email ingestion
- **Row Level Security (RLS)**: Database-level tenant isolation
- **Background Processing**: Async classification and notifications
- **Audit Logging**: Track all user actions
- **RESTful API**: Complete backend API for all operations

## Architecture

```
Frontend (Vite + Vanilla JS)
        ↓
Backend API (FastAPI)
        ↓
    ┌──────────────┬──────────────────┬──────────────┐
    ↓              ↓                  ↓              ↓
Email Processor   Sentiment Engine   Database      Supabase Auth
    ↓              ↓                  ↓
SendGrid       NLP Models         PostgreSQL
Webhook        (Keywords +         (Multi-tenant
               Heuristics)          with RLS)
```

## Database Schema

### Core Tables
- `tenants` - Client organizations
- `tenant_users` - User-tenant relationships
- `subscription_plans` - Billing tiers (Free/Pro/Enterprise)
- `email_integrations` - Connected email providers
- `feedback_items` - Customer support messages with analysis
- `alerts` - High-priority notifications
- `exports` - Export job tracking
- `audit_logs` - Activity history
- `auto_reply_templates` - Automated response templates
- `feedback_comments` - Internal notes on feedback

## API Endpoints

### Authentication
- Uses Supabase Auth with JWT tokens
- Multi-tenant access control via `tenant_users` table

### Webhooks
- `POST /webhook/sendgrid` - Inbound email from SendGrid

### Feedback Management
- `GET /api/feedback` - List feedback with filters
- `GET /api/feedback/{id}` - Get feedback details
- `POST /api/feedback/{id}/satisfy` - Mark as satisfied
- `POST /api/feedback/{id}/comment` - Add internal comment

### Analytics
- `GET /api/analytics/summary` - Dashboard statistics
- `GET /api/analytics/trends` - Time-series data

### Integrations
- `GET /api/integrations` - List email integrations
- `POST /api/integrations` - Add new integration

### Exports
- `POST /api/exports` - Create export job
- `GET /api/exports/{id}` - Check export status

## Email Ingestion Flow

1. **SendGrid Webhook**: Email arrives → SendGrid posts to `/webhook/sendgrid`
2. **Normalization**: Extract subject, body, sender, metadata
3. **Classification Pipeline**:
   - Sentiment Analysis (positive/negative/neutral + score)
   - Urgency Detection (low/medium/high + score)
   - Intent Classification (complaint/praise/question/request)
   - Priority Calculation (0-100 based on sentiment + urgency)
4. **Storage**: Save to `feedback_items` table
5. **Alerts**: Create alert if high urgency + negative sentiment
6. **Real-time**: Broadcast to dashboard (future: WebSocket)

## Sentiment Analysis Engine

### Algorithm
- **Lexicon-based approach** with keyword matching
- Positive/negative word dictionaries
- Intensifier detection (very, extremely, really)
- Negation handling (not, never, no)
- Confidence scoring based on sentiment word density

### Urgency Detection
- Keyword matching (urgent, asap, emergency, immediately)
- Exclamation mark detection
- ALL CAPS text analysis
- Combined score → low/medium/high classification

### Intent Classification
- Multi-label classification
- Keyword sets for: complaint, praise, question, request
- Highest score determines intent
- Fallback to "general" if no strong signal

## Setup Instructions

### Prerequisites
- Node.js 18+
- Python 3.11+
- Supabase account (database already provisioned)

### Installation

1. **Install Node dependencies**:
```bash
npm install
```

2. **Install Python dependencies**:
```bash
pip install -r requirements.txt
```

3. **Environment Variables**:
Already configured in `.env`:
- `VITE_SUPABASE_URL` - Supabase project URL
- `VITE_SUPABASE_ANON_KEY` - Supabase anon key

### Running the Application

1. **Start Backend API**:
```bash
python -m uvicorn api.main:app --reload --port 8000
```

2. **Start Frontend Dev Server**:
```bash
npm run dev
```

The application will be available at `http://localhost:5173`

### Building for Production
```bash
npm run build
```

## Usage Guide

### 1. Create Account
- Sign up with email, password, and organization name
- Free plan: 100 feedback items/month, 1 integration
- Automatically creates tenant and links user

### 2. Connect Email Integration
- Go to Integrations section
- Configure SendGrid inbound parse webhook
- Point to: `https://your-domain.com/webhook/sendgrid`

### 3. Receive Feedback
- Emails automatically ingested and analyzed
- View in Dashboard or Feedback Items
- Real-time updates on new submissions

### 4. Manage Feedback
- Click any feedback item to view details
- Mark as "Satisfied" when resolved
- Add internal comments for team collaboration
- Filter by sentiment, urgency, or status

### 5. Analytics
- Dashboard shows live statistics
- Sentiment distribution (positive/negative/neutral)
- High-priority count
- Satisfaction rate

### 6. Export Data (Pro)
- Create filtered exports in CSV or JSON
- Background processing for large datasets
- Download when ready

## Security Features

### Authentication & Authorization
- Supabase Auth with email/password
- JWT token-based API access
- Automatic token refresh

### Multi-Tenant Isolation
- Row Level Security (RLS) on all tables
- Users can only access their tenant's data
- Enforced at database level

### Data Protection
- Encrypted auth tokens
- HTTPS only in production
- Audit logging for compliance

## Subscription Plans

### Free
- 100 feedback items/month
- 1 email integration
- 30 days data retention
- Basic dashboard

### Pro ($29.99/month)
- 10,000 feedback items/month
- 5 email integrations
- 365 days retention
- Export to CSV/JSON
- Auto-reply templates
- Real-time updates

### Enterprise ($99.99/month)
- Unlimited feedback items
- Unlimited integrations
- Unlimited retention
- All Pro features
- SSO support
- Custom ML models
- Priority support

## Email Provider Integration Guide

### SendGrid Inbound Parse
1. Log in to SendGrid → Settings → Inbound Parse
2. Add new hostname: `your-domain.com`
3. Set URL: `https://your-api.com/webhook/sendgrid`
4. Configure MX records in DNS
5. Test with sample email

### Gmail API (Future)
- OAuth2 authentication
- Gmail Push notifications via Pub/Sub
- Real-time message fetch

### Microsoft Graph (Future)
- Office 365 integration
- Webhook subscriptions
- OAuth2 delegated permissions

### IMAP/IDLE (Future)
- Generic email provider support
- Near real-time polling
- Fallback for providers without webhooks

## ML & NLP Details

### Current Approach
- **Keyword-based** classification (fast, no external dependencies)
- Positive words: good, great, excellent, thank, appreciate, etc.
- Negative words: bad, terrible, problem, broken, failed, etc.
- Urgency keywords: urgent, asap, emergency, critical, etc.

### Future Enhancements
- Fine-tuned transformer models (BERT/RoBERTa)
- Cloud NLP APIs (AWS Comprehend, Google NL)
- Named Entity Recognition (extract order IDs, accounts)
- Custom models trained on tenant's data
- Multi-language support

## API Authentication Example

```javascript
// Get session token
const { data: { session } } = await supabase.auth.getSession();
const token = session.access_token;

// Call API
const response = await fetch('http://localhost:8000/api/feedback', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});
```

## Development Roadmap

### Phase 1 (MVP) - Complete ✓
- Multi-tenant auth and database
- SendGrid webhook integration
- Sentiment + urgency analysis
- Dashboard with filters
- Mark satisfied functionality

### Phase 2 (In Progress)
- Real-time WebSocket updates
- Export functionality
- Auto-reply templates
- Gmail API integration

### Phase 3 (Future)
- Advanced ML models
- Microsoft Graph integration
- Mobile app
- Custom alerts and rules
- Team collaboration features
- SLA tracking

## Monitoring & Debugging

### Logs
- Backend logs: Console output from FastAPI
- Supabase logs: Dashboard → Logs
- Audit trail: `audit_logs` table

### Key Metrics
- Email ingestion rate
- Classification accuracy
- API response times
- Error rates
- Queue depth

## Troubleshooting

### Emails not appearing?
1. Check SendGrid webhook is configured
2. Verify endpoint is reachable (test with curl)
3. Check backend logs for errors
4. Verify integration exists in database

### Dashboard not loading?
1. Check user is in `tenant_users` table
2. Verify Supabase credentials in `.env`
3. Check browser console for errors
4. Confirm RLS policies allow access

### Classification seems wrong?
1. Review keyword dictionaries in `sentiment_engine.py`
2. Add domain-specific terms
3. Consider training custom models
4. Check text preprocessing logic

## Contributing

This is a production MVP. Future enhancements welcome:
- Additional email providers
- Improved ML models
- UI/UX improvements
- Performance optimizations

## License

Proprietary - All Rights Reserved

## Support

For technical support or questions:
- Email: support@yourdomain.com
- Documentation: https://docs.yourdomain.com
