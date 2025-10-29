const SUPABASE_URL = 'https://zcezahdnvfaemarwdhdw.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjZXphaGRudmZhZW1hcndkaGR3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3NDg1NTYsImV4cCI6MjA3NzMyNDU1Nn0.jVzTKifZ8irV0_ObLmRBBxKgK8AS6Jq-YqgOauPtVM0';
const API_BASE_URL = '';

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

let currentUser = null;
let authToken = null;
let sentimentChart = null;

const elements = {
    authContainer: document.getElementById('authContainer'),
    dashboardContainer: document.getElementById('dashboardContainer'),
    loginForm: document.getElementById('loginForm'),
    signupForm: document.getElementById('signupForm'),
    errorMessage: document.getElementById('errorMessage'),
    successMessage: document.getElementById('successMessage'),
    loginEmail: document.getElementById('loginEmail'),
    loginPassword: document.getElementById('loginPassword'),
    loginBtn: document.getElementById('loginBtn'),
    signupEmail: document.getElementById('signupEmail'),
    signupPassword: document.getElementById('signupPassword'),
    signupBtn: document.getElementById('signupBtn'),
    showSignup: document.getElementById('showSignup'),
    showLogin: document.getElementById('showLogin'),
    logoutBtn: document.getElementById('logoutBtn'),
    userEmail: document.getElementById('userEmail'),
    totalAnalyses: document.getElementById('totalAnalyses'),
    apiCallsRemaining: document.getElementById('apiCallsRemaining'),
    subscriptionTier: document.getElementById('subscriptionTier'),
    textInput: document.getElementById('textInput'),
    analyzeBtn: document.getElementById('analyzeBtn'),
    resultCard: document.getElementById('resultCard'),
    sentimentBadge: document.getElementById('sentimentBadge'),
    confidenceScore: document.getElementById('confidenceScore'),
    scoreFill: document.getElementById('scoreFill'),
    metadataInfo: document.getElementById('metadataInfo'),
    historyList: document.getElementById('historyList'),
    upgradeBtn: document.getElementById('upgradeBtn'),
    paymentModal: document.getElementById('paymentModal'),
    closeModal: document.getElementById('closeModal'),
    proceedPayment: document.getElementById('proceedPayment'),
    chartContainer: document.getElementById('chartContainer')
};

function showError(message) {
    elements.errorMessage.textContent = message;
    elements.errorMessage.style.display = 'block';
    elements.successMessage.style.display = 'none';
    setTimeout(() => {
        elements.errorMessage.style.display = 'none';
    }, 5000);
}

function showSuccess(message) {
    elements.successMessage.textContent = message;
    elements.successMessage.style.display = 'block';
    elements.errorMessage.style.display = 'none';
    setTimeout(() => {
        elements.successMessage.style.display = 'none';
    }, 5000);
}

elements.showSignup.addEventListener('click', () => {
    elements.loginForm.style.display = 'none';
    elements.signupForm.style.display = 'block';
    elements.errorMessage.style.display = 'none';
});

elements.showLogin.addEventListener('click', () => {
    elements.signupForm.style.display = 'none';
    elements.loginForm.style.display = 'block';
    elements.errorMessage.style.display = 'none';
});

elements.signupBtn.addEventListener('click', async () => {
    const email = elements.signupEmail.value.trim();
    const password = elements.signupPassword.value;

    if (!email || !password) {
        showError('Please fill in all fields');
        return;
    }

    if (password.length < 6) {
        showError('Password must be at least 6 characters');
        return;
    }

    elements.signupBtn.disabled = true;
    elements.signupBtn.innerHTML = '<span class="loading"></span>';

    try {
        const { data, error } = await supabase.auth.signUp({
            email,
            password
        });

        if (error) throw error;

        if (data.user) {
            await supabase.from('users').insert([{
                id: data.user.id,
                email: data.user.email,
                subscription_tier: 'free',
                api_calls_remaining: 10
            }]);

            showSuccess('Account created successfully! Please sign in.');
            elements.signupForm.style.display = 'none';
            elements.loginForm.style.display = 'block';
            elements.signupEmail.value = '';
            elements.signupPassword.value = '';
        }
    } catch (error) {
        showError(error.message);
    } finally {
        elements.signupBtn.disabled = false;
        elements.signupBtn.textContent = 'Create Account';
    }
});

elements.loginBtn.addEventListener('click', async () => {
    const email = elements.loginEmail.value.trim();
    const password = elements.loginPassword.value;

    if (!email || !password) {
        showError('Please fill in all fields');
        return;
    }

    elements.loginBtn.disabled = true;
    elements.loginBtn.innerHTML = '<span class="loading"></span>';

    try {
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password
        });

        if (error) throw error;

        currentUser = data.user;
        authToken = data.session.access_token;
        showDashboard();
    } catch (error) {
        showError(error.message);
    } finally {
        elements.loginBtn.disabled = false;
        elements.loginBtn.textContent = 'Sign In';
    }
});

elements.logoutBtn.addEventListener('click', async () => {
    await supabase.auth.signOut();
    currentUser = null;
    authToken = null;
    elements.authContainer.style.display = 'flex';
    elements.dashboardContainer.style.display = 'none';
    elements.loginEmail.value = '';
    elements.loginPassword.value = '';
});

async function showDashboard() {
    elements.authContainer.style.display = 'none';
    elements.dashboardContainer.style.display = 'block';
    elements.userEmail.textContent = currentUser.email;

    await loadUserStats();
    await loadHistory();
}

async function loadUserStats() {
    try {
        const response = await fetch(`${API_BASE_URL}/api/stats`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (!response.ok) throw new Error('Failed to load stats');

        const stats = await response.json();
        elements.totalAnalyses.textContent = stats.total_analyses;
        elements.apiCallsRemaining.textContent = stats.api_calls_remaining;
        elements.subscriptionTier.textContent = stats.subscription_tier;

        if (stats.total_analyses > 0 && stats.recent_analyses.length > 0) {
            updateChart(stats.recent_analyses);
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

async function loadHistory() {
    try {
        const response = await fetch(`${API_BASE_URL}/api/analyses?limit=10`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (!response.ok) throw new Error('Failed to load history');

        const analyses = await response.json();
        renderHistory(analyses);
    } catch (error) {
        console.error('Error loading history:', error);
        elements.historyList.innerHTML = '<p style="color: var(--text-secondary); text-align: center;">No analyses yet</p>';
    }
}

function renderHistory(analyses) {
    if (analyses.length === 0) {
        elements.historyList.innerHTML = '<p style="color: var(--text-secondary); text-align: center;">No analyses yet</p>';
        return;
    }

    elements.historyList.innerHTML = analyses.map(analysis => `
        <div class="history-item">
            <div class="text-preview">${analysis.text.substring(0, 60)}${analysis.text.length > 60 ? '...' : ''}</div>
            <div class="meta">
                <span class="sentiment-badge sentiment-${analysis.sentiment_label}">${analysis.sentiment_label}</span>
                <span>${new Date(analysis.created_at).toLocaleDateString()}</span>
            </div>
        </div>
    `).join('');
}

elements.analyzeBtn.addEventListener('click', async () => {
    const text = elements.textInput.value.trim();

    if (!text) {
        showError('Please enter text to analyze');
        return;
    }

    elements.analyzeBtn.disabled = true;
    elements.analyzeBtn.innerHTML = '<span class="loading"></span>';

    try {
        const response = await fetch(`${API_BASE_URL}/api/analyze`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ text })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Analysis failed');
        }

        const result = await response.json();
        displayResult(result);
        await loadUserStats();
        await loadHistory();

        elements.textInput.value = '';
    } catch (error) {
        showError(error.message);
    } finally {
        elements.analyzeBtn.disabled = false;
        elements.analyzeBtn.textContent = 'Analyze Sentiment';
    }
});

function displayResult(result) {
    elements.resultCard.style.display = 'block';
    elements.sentimentBadge.textContent = result.sentiment_label;
    elements.sentimentBadge.className = `sentiment-badge sentiment-${result.sentiment_label}`;

    elements.confidenceScore.textContent = `Confidence: ${(result.confidence * 100).toFixed(1)}%`;

    const scorePercent = ((result.sentiment_score + 1) / 2) * 100;
    elements.scoreFill.style.width = `${scorePercent}%`;

    let color = '#94a3b8';
    if (result.sentiment_label === 'positive') color = '#10b981';
    else if (result.sentiment_label === 'negative') color = '#ef4444';

    elements.scoreFill.style.backgroundColor = color;

    elements.metadataInfo.innerHTML = `
        <strong>Score:</strong> ${result.sentiment_score.toFixed(3)} |
        <strong>Words:</strong> ${result.metadata.word_count} |
        <strong>Positive:</strong> ${result.metadata.positive_words} |
        <strong>Negative:</strong> ${result.metadata.negative_words}
    `;

    elements.resultCard.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function updateChart(analyses) {
    elements.chartContainer.style.display = 'block';

    const ctx = document.getElementById('sentimentChart').getContext('2d');

    if (sentimentChart) {
        sentimentChart.destroy();
    }

    const labels = analyses.map((_, i) => `Analysis ${analyses.length - i}`);
    const scores = analyses.reverse().map(a => a.sentiment_score);

    sentimentChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Sentiment Score',
                data: scores,
                borderColor: '#2563eb',
                backgroundColor: 'rgba(37, 99, 235, 0.1)',
                tension: 0.4,
                fill: true
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: false
                },
                title: {
                    display: true,
                    text: 'Recent Sentiment Trends'
                }
            },
            scales: {
                y: {
                    min: -1,
                    max: 1,
                    ticks: {
                        callback: function(value) {
                            if (value === 1) return 'Positive';
                            if (value === 0) return 'Neutral';
                            if (value === -1) return 'Negative';
                            return value;
                        }
                    }
                }
            }
        }
    });
}

elements.upgradeBtn.addEventListener('click', () => {
    elements.paymentModal.style.display = 'flex';
});

elements.closeModal.addEventListener('click', () => {
    elements.paymentModal.style.display = 'none';
});

let selectedTier = null;
let selectedPrice = null;

document.querySelectorAll('.pricing-option').forEach(option => {
    option.addEventListener('click', () => {
        document.querySelectorAll('.pricing-option').forEach(o => o.classList.remove('selected'));
        option.classList.add('selected');
        selectedTier = option.dataset.tier;
        selectedPrice = option.dataset.price;
    });
});

elements.proceedPayment.addEventListener('click', async () => {
    if (!selectedTier) {
        alert('Please select a plan');
        return;
    }

    elements.proceedPayment.disabled = true;
    elements.proceedPayment.innerHTML = '<span class="loading"></span>';

    try {
        const { data, error } = await supabase.from('payments').insert([{
            user_id: currentUser.id,
            amount: parseFloat(selectedPrice),
            currency: 'usd',
            status: 'completed',
            subscription_tier: selectedTier,
            stripe_payment_id: 'sim_' + Date.now()
        }]).select();

        if (error) throw error;

        await supabase.from('users').update({
            subscription_tier: selectedTier,
            api_calls_remaining: selectedTier === 'pro' ? 1000 : 999999
        }).eq('id', currentUser.id);

        showSuccess('Payment successful! Your plan has been upgraded.');
        elements.paymentModal.style.display = 'none';
        await loadUserStats();
    } catch (error) {
        showError('Payment failed: ' + error.message);
    } finally {
        elements.proceedPayment.disabled = false;
        elements.proceedPayment.textContent = 'Proceed to Payment';
    }
});

supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN' && session) {
        currentUser = session.user;
        authToken = session.access_token;
        showDashboard();
    } else if (event === 'SIGNED_OUT') {
        currentUser = null;
        authToken = null;
        elements.authContainer.style.display = 'flex';
        elements.dashboardContainer.style.display = 'none';
    }
});

(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (session) {
        currentUser = session.user;
        authToken = session.access_token;
        showDashboard();
    }
})();
