# awakenU-sentiment-analysis/app.py
from flask import Flask, jsonify
from flask_cors import CORS # Don't forget to install: pip install Flask-Cors
from api.payment_gateway.payment_routes import payment_bp # Import your blueprint
import os

app = Flask(__name__)
CORS(app) # Enable CORS for your Flask app

# Register the payment blueprint
app.register_blueprint(payment_bp, url_prefix='/api/payment')

@app.route('/')
def home():
    return jsonify({"message": "Welcome to awakenU Sentiment Analysis API!"})

# Add other existing routes here

if __name__ == '__main__':
    # Load environment variables (e.g., from a .env file if using python-dotenv)
    # pip install python-dotenv
    # from dotenv import load_dotenv
    # load_dotenv()

    # Ensure environment variables are set for Razorpay
    # Example: export RAZORPAY_KEY_ID="rzp_test_..."
    # Example: export RAZORPAY_KEY_SECRET="your_secret_..."
    # Or place them in a .env file and use load_dotenv()

    app.run(debug=True, port=5000) # Or your desired port