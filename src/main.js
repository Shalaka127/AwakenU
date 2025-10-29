import { createClient } from '@supabase/supabase-js';
import { io } from 'socket.io-client';
import { Chart } from 'chart.js/auto';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://zcezahdnvfaemarwdhdw.supabase.co';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjZXphaGRudmZhZW1hcndkaGR3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3NDg1NTYsImV4cCI6MjA3NzMyNDU1Nn0.jVzTKifZ8irV0_ObLmRBBxKgK8AS6Jq-YqgOauPtVM0';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

let currentUser = null;
let currentTenant = null;
let socket = null;

function renderLoginPage() {
    const loginPage = document.getElementById('loginPage');
    loginPage.innerHTML = `
        <div class="auth-card">
            <div class="auth-logo">
                <div class="auth-logo-icon">📊</div>
            </div>
            <h1 class="auth-title">AwakenU</h1>
            <p class="auth-subtitle">Welcome back! Please sign in to your account.</p>

            <div id="authMessage" class="message" style="display: none;"></div>

            <div class="role-selector">
                <button class="role-btn active" data-role="client">
                    <span class="role-label">Client</span>
                    <span class="role-desc">View your data</span>
                </button>
                <button class="role-btn" data-role="admin">
                    <span class="role-label">Admin</span>
                    <span class="role-desc">Manage system</span>
                </button>
            </div>

            <form id="loginForm">
                <div class="form-group">
                    <label class="form-label">Email Address</label>
                    <input type="email" class="form-input" id="loginEmail" placeholder="Enter your email" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Password</label>
                    <input type="password" class="form-input" id="loginPassword" placeholder="Enter your password" required>
                </div>
                <div class="form-checkbox">
                    <input type="checkbox" id="rememberMe">
                    <label for="rememberMe">Remember me</label>
                </div>
                <button type="submit" class="btn">Sign In</button>
            </form>

            <div class="auth-divider">
                <span>Or continue with</span>
            </div>

            <button class="btn btn-google">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M10.2 8.2v3.6h5.1c-.2 1.1-1.2 3.2-5.1 3.2-3.1 0-5.6-2.5-5.6-5.7S7.1 3.6 10.2 3.6c1.7 0 2.9.7 3.6 1.4l2.8-2.7C14.9.7 12.8 0 10.2 0 4.7 0 .2 4.5.2 10s4.5 10 10 10c5.8 0 9.6-4.1 9.6-9.8 0-.7-.1-1.2-.1-1.7h-9.5v-.3z"/>
                </svg>
                Sign in with Google
            </button>

            <div class="demo-credentials">
                <strong>Demo Credentials:</strong>
                Client: client@example.com / client123<br>
                Admin: admin@sentily.com / admin123
            </div>

            <div style="text-align: center; margin-top: 20px; padding-top: 20px; border-top: 1px solid rgba(139, 92, 246, 0.2);">
                <p style="color: #a8a3b8; font-size: 14px;">
                    Don't have an account? <a href="#" id="showSignup" style="color: #8b5cf6; text-decoration: none; font-weight: 600;">Sign up</a>
                </p>
            </div>
        </div>
    `;

    const roleButtons = document.querySelectorAll('.role-btn');
    roleButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            roleButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        });
    });

    const googleBtn = document.querySelector('.btn-google');
    googleBtn.addEventListener('click', handleGoogleSignIn);

    const signupLink = document.getElementById('showSignup');
    signupLink.addEventListener('click', (e) => {
        e.preventDefault();
        renderSignupPage();
    });

    document.getElementById('loginForm').addEventListener('submit', handleLogin);
}

function renderSignupPage() {
    const loginPage = document.getElementById('loginPage');
    loginPage.innerHTML = `
        <div class="auth-card">
            <div class="auth-logo">
                <div class="auth-logo-icon">📊</div>
            </div>
            <h1 class="auth-title">AwakenU</h1>
            <p class="auth-subtitle">Create your account to get started.</p>

            <div id="authMessage" class="message" style="display: none;"></div>

            <form id="signupForm">
                <div class="form-group">
                    <label class="form-label">Full Name</label>
                    <input type="text" class="form-input" id="signupName" placeholder="Enter your full name" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Email Address</label>
                    <input type="email" class="form-input" id="signupEmail" placeholder="Enter your email" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Password</label>
                    <input type="password" class="form-input" id="signupPassword" placeholder="Create a password (min 6 characters)" required minlength="6">
                </div>
                <div class="form-group">
                    <label class="form-label">Organization Name</label>
                    <input type="text" class="form-input" id="signupOrg" placeholder="Enter your organization name" required>
                </div>
                <button type="submit" class="btn">Create Account</button>
            </form>

            <div style="text-align: center; margin-top: 20px; padding-top: 20px; border-top: 1px solid rgba(139, 92, 246, 0.2);">
                <p style="color: #a8a3b8; font-size: 14px;">
                    Already have an account? <a href="#" id="showLogin" style="color: #8b5cf6; text-decoration: none; font-weight: 600;">Sign in</a>
                </p>
            </div>
        </div>
    `;

    const loginLink = document.getElementById('showLogin');
    loginLink.addEventListener('click', (e) => {
        e.preventDefault();
        renderLoginPage();
    });

    document.getElementById('signupForm').addEventListener('submit', handleSignup);
}

async function handleSignup(e) {
    e.preventDefault();

    const name = document.getElementById('signupName').value.trim();
    const email = document.getElementById('signupEmail').value.trim();
    const password = document.getElementById('signupPassword').value;
    const orgName = document.getElementById('signupOrg').value.trim();

    try {
        showMessage('Creating your account...', 'info');

        const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options: {
                data: {
                    full_name: name,
                    organization_name: orgName
                }
            }
        });

        if (error) throw error;

        if (data.user) {
            const orgSlug = orgName.toLowerCase().replace(/[^a-z0-9]+/g, '-');
            const orgDomain = email.split('@')[1];

            const { data: tenant, error: tenantError } = await supabase
                .from('tenants')
                .insert({
                    name: orgName,
                    slug: orgSlug,
                    domain: orgDomain,
                    is_active: true
                })
                .select()
                .single();

            if (tenantError) throw tenantError;

            const { error: userError } = await supabase
                .from('users')
                .insert({
                    id: data.user.id,
                    email: email,
                    full_name: name
                });

            if (userError) throw userError;

            const { error: memberError } = await supabase
                .from('tenant_memberships')
                .insert({
                    user_id: data.user.id,
                    tenant_id: tenant.id,
                    role: 'admin',
                    is_active: true
                });

            if (memberError) throw memberError;

            showMessage('Account created successfully! Signing you in...', 'success');

            setTimeout(async () => {
                currentUser = data.user;
                await loadDashboard();
            }, 1500);
        }
    } catch (error) {
        console.error('Signup error:', error);
        showMessage(error.message, 'error');
    }
}

async function handleLogin(e) {
    e.preventDefault();

    const email = document.getElementById('loginEmail').value.trim();
    const password = document.getElementById('loginPassword').value;

    try {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });

        if (error) throw error;

        currentUser = data.user;
        await loadDashboard();
    } catch (error) {
        showMessage(error.message, 'error');
    }
}

async function handleGoogleSignIn() {
    showMessage('Google Sign-In is not configured yet. Please use the demo credentials below to sign in.', 'info');
}

async function loadDashboard() {
    try {
        const { data: membership, error } = await supabase
            .from('tenant_memberships')
            .select('tenant_id, role, tenants(name)')
            .eq('user_id', currentUser.id)
            .eq('is_active', true)
            .maybeSingle();

        if (error) {
            console.error('Membership query error:', error);
            showMessage('Error loading tenant: ' + error.message, 'error');
            return;
        }

        if (!membership) {
            showMessage('No tenant found for your account. Please contact support.', 'error');
            return;
        }

        currentTenant = membership.tenant_id;

        document.getElementById('loginPage').style.display = 'none';
        document.getElementById('dashboardPage').style.display = 'flex';

        renderDashboard();
        await loadAnalytics();
    } catch (error) {
        console.error('Dashboard load error:', error);
        showMessage('Error loading dashboard', 'error');
    }
}

function renderDashboard() {
    const dashboardPage = document.getElementById('dashboardPage');
    dashboardPage.innerHTML = `
        <aside class="sidebar">
            <div class="sidebar-header">
                <div class="sidebar-logo">
                    <div class="sidebar-logo-icon">📊</div>
                    <div class="sidebar-logo-text">
                        <div class="sidebar-logo-title">AwakenU</div>
                        <div class="sidebar-logo-subtitle">Hybrid Sentiment Analysis Dashboard</div>
                    </div>
                </div>
            </div>
            <nav class="sidebar-nav">
                <div class="nav-item active" data-page="dashboard">
                    <span class="nav-icon">📈</span>
                    <span>Dashboard</span>
                </div>
                <div class="nav-item" data-page="feedback">
                    <span class="nav-icon">💬</span>
                    <span>Feedback Explorer</span>
                </div>
                <div class="nav-item" data-page="products">
                    <span class="nav-icon">📦</span>
                    <span>Products</span>
                </div>
                <div class="nav-item" data-page="alerts">
                    <span class="nav-icon">🔔</span>
                    <span>Alerts</span>
                </div>
                <div class="nav-item" data-page="settings">
                    <span class="nav-icon">⚙️</span>
                    <span>Settings</span>
                </div>
            </nav>
            <div class="sidebar-footer">
                <div class="system-status">
                    <span class="status-dot"></span>
                    <div>
                        <div style="font-weight: 600; color: var(--success);">System Online</div>
                        <div style="opacity: 0.7;">All services operational</div>
                    </div>
                </div>
            </div>
        </aside>

        <main class="main-content">
            <header class="topbar">
                <div class="search-box">
                    <span class="search-icon">🔍</span>
                    <input type="text" class="search-input" placeholder="Search feedback, products, or customers...">
                </div>
                <div class="topbar-actions">
                    <button class="icon-btn">
                        <span>💼</span>
                    </button>
                    <button class="icon-btn">
                        <span>⚙️</span>
                    </button>
                    <button class="icon-btn">
                        <span>🔔</span>
                        <span class="notification-badge">3</span>
                    </button>
                    <div class="user-menu" id="userMenuToggle">
                        <div class="user-avatar">${currentUser.email.charAt(0).toUpperCase()}</div>
                        <div class="user-info">
                            <div class="user-name">${currentUser.email.split('@')[0]}</div>
                            <div class="user-role">Client</div>
                        </div>
                        <span>▼</span>
                        <div class="user-dropdown" id="userDropdown">
                            <div class="dropdown-header">
                                <div class="user-name">${currentUser.email.split('@')[0]}</div>
                                <div class="dropdown-email">${currentUser.email}</div>
                            </div>
                            <div class="dropdown-item">
                                <span>👤</span> Profile Settings
                            </div>
                            <div class="dropdown-item">
                                <span>⚙️</span> Preferences
                            </div>
                            <div class="dropdown-divider"></div>
                            <div class="dropdown-item danger" id="logoutBtn">
                                <span>🚪</span> Sign Out
                            </div>
                        </div>
                    </div>
                </div>
            </header>

            <div class="content-area" id="contentArea">
                <!-- Dynamic content -->
            </div>
        </main>
    `;

    document.getElementById('userMenuToggle').addEventListener('click', () => {
        document.getElementById('userDropdown').classList.toggle('active');
    });

    document.getElementById('logoutBtn').addEventListener('click', async () => {
        await supabase.auth.signOut();
        location.reload();
    });

    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => {
            document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
            item.classList.add('active');

            const page = item.dataset.page;
            loadPage(page);
        });
    });

    loadPage('dashboard');
}

function loadPage(page) {
    const contentArea = document.getElementById('contentArea');

    switch(page) {
        case 'dashboard':
            renderDashboardPage(contentArea);
            break;
        case 'feedback':
            renderFeedbackPage(contentArea);
            break;
        default:
            contentArea.innerHTML = `
                <div class="page-header">
                    <h1 class="page-title">${page.charAt(0).toUpperCase() + page.slice(1)}</h1>
                    <p class="page-subtitle">Coming soon...</p>
                </div>
            `;
    }
}

function renderDashboardPage(container) {
    container.innerHTML = `
        <div class="page-header">
            <h1 class="page-title">Dashboard</h1>
            <p class="page-subtitle">Real-time sentiment analysis overview</p>
            <div class="page-actions">
                <button class="btn-primary">
                    <span>📥</span> Export Data
                </button>
            </div>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-header">
                    <span class="stat-icon">💬</span>
                </div>
                <div class="stat-label">Total Feedback</div>
                <div class="stat-value" id="totalFeedback">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-header">
                    <span class="stat-icon">😊</span>
                </div>
                <div class="stat-label">Positive Sentiment</div>
                <div class="stat-value" id="positiveFeedback">0</div>
                <span class="stat-badge badge-success">Good</span>
            </div>
            <div class="stat-card">
                <div class="stat-header">
                    <span class="stat-icon">😟</span>
                </div>
                <div class="stat-label">Negative Sentiment</div>
                <div class="stat-value" id="negativeFeedback">0</div>
                <span class="stat-badge badge-danger">Needs Attention</span>
            </div>
            <div class="stat-card">
                <div class="stat-header">
                    <span class="stat-icon">⚡</span>
                </div>
                <div class="stat-label">High Priority</div>
                <div class="stat-value" id="highPriority">0</div>
                <span class="stat-badge badge-danger">Urgent</span>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h3 class="card-title">Sentiment Trends Over Time</h3>
            </div>
            <div class="chart-container">
                <canvas id="trendsChart"></canvas>
            </div>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">Sentiment Distribution</h3>
                </div>
                <div class="chart-container">
                    <canvas id="distributionChart"></canvas>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">High Urgency Complaints</h3>
                </div>
                <div id="urgentList">
                    <div class="empty-state">
                        <div class="empty-icon">📭</div>
                        <p>No urgent items</p>
                    </div>
                </div>
            </div>
        </div>
    `;

    initializeCharts();
}

function renderFeedbackPage(container) {
    container.innerHTML = `
        <div class="page-header">
            <h1 class="page-title">Feedback Explorer</h1>
            <p class="page-subtitle">View and manage customer support messages</p>
        </div>

        <div class="filters">
            <button class="filter-btn active">All</button>
            <button class="filter-btn">Positive</button>
            <button class="filter-btn">Negative</button>
            <button class="filter-btn">Neutral</button>
            <button class="filter-btn">High Priority</button>
        </div>

        <div class="card">
            <div id="feedbackTable">
                <div class="loading">
                    <div class="spinner"></div>
                </div>
            </div>
        </div>
    `;

    loadFeedbackItems();
}

async function loadAnalytics() {
    try {
        const { data: feedback } = await supabase
            .from('feedback_items')
            .select('sentiment, urgency')
            .eq('tenant_id', currentTenant);

        if (!feedback || feedback.length === 0) {
            document.getElementById('totalFeedback').textContent = '0';
            document.getElementById('positiveFeedback').textContent = '0';
            document.getElementById('negativeFeedback').textContent = '0';
            document.getElementById('highPriority').textContent = '0';
            return;
        }

        const total = feedback.length;
        const positive = feedback.filter(f => f.sentiment === 'positive').length;
        const negative = feedback.filter(f => f.sentiment === 'negative').length;
        const highUrgency = feedback.filter(f => f.urgency === 'high').length;

        document.getElementById('totalFeedback').textContent = total;
        document.getElementById('positiveFeedback').textContent = positive;
        document.getElementById('negativeFeedback').textContent = negative;
        document.getElementById('highPriority').textContent = highUrgency;
    } catch (error) {
        console.error('Analytics error:', error);
    }
}

async function loadFeedbackItems() {
    try {
        const { data: items } = await supabase
            .from('feedback_items')
            .select('*')
            .eq('tenant_id', currentTenant)
            .order('received_at', { ascending: false })
            .limit(50);

        const feedbackTable = document.getElementById('feedbackTable');

        if (!items || items.length === 0) {
            feedbackTable.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">📭</div>
                    <p>No feedback items yet</p>
                </div>
            `;
            return;
        }

        feedbackTable.innerHTML = `
            <div class="table-container">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Subject</th>
                            <th>Sender</th>
                            <th>Sentiment</th>
                            <th>Urgency</th>
                            <th>Status</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${items.map(item => `
                            <tr>
                                <td>${item.subject || 'No Subject'}</td>
                                <td>${item.sender_email}</td>
                                <td><span class="badge badge-${item.sentiment}">${item.sentiment}</span></td>
                                <td><span class="badge badge-${item.urgency}">${item.urgency}</span></td>
                                <td>${item.is_satisfied ? '✅ Satisfied' : '⏳ Open'}</td>
                                <td>${new Date(item.received_at).toLocaleDateString()}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        `;
    } catch (error) {
        console.error('Feedback error:', error);
    }
}

function initializeCharts() {
    const trendsCtx = document.getElementById('trendsChart');
    const distributionCtx = document.getElementById('distributionChart');

    if (trendsCtx) {
        new Chart(trendsCtx, {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                datasets: [
                    {
                        label: 'Positive',
                        data: [65, 59, 80, 81, 56, 55],
                        borderColor: '#10b981',
                        backgroundColor: 'rgba(16, 185, 129, 0.1)',
                        tension: 0.4
                    },
                    {
                        label: 'Negative',
                        data: [28, 48, 40, 19, 86, 27],
                        borderColor: '#ef4444',
                        backgroundColor: 'rgba(239, 68, 68, 0.1)',
                        tension: 0.4
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        labels: {
                            color: '#a8a3b8'
                        }
                    }
                },
                scales: {
                    y: {
                        grid: {
                            color: 'rgba(139, 92, 246, 0.05)'
                        },
                        ticks: {
                            color: '#a8a3b8'
                        }
                    },
                    x: {
                        grid: {
                            color: 'rgba(139, 92, 246, 0.05)'
                        },
                        ticks: {
                            color: '#a8a3b8'
                        }
                    }
                }
            }
        });
    }

    if (distributionCtx) {
        new Chart(distributionCtx, {
            type: 'doughnut',
            data: {
                labels: ['Positive', 'Negative', 'Neutral'],
                datasets: [{
                    data: [48, 52, 0],
                    backgroundColor: ['#10b981', '#ef4444', '#8b5cf6']
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            color: '#a8a3b8'
                        }
                    }
                }
            }
        });
    }
}

function showMessage(text, type) {
    const msg = document.getElementById('authMessage');
    if (msg) {
        msg.textContent = text;
        msg.className = `message ${type}`;
        msg.style.display = 'block';
        setTimeout(() => msg.style.display = 'none', 5000);
    }
}

(async () => {
    console.log('App initializing...');

    try {
        const { data: { session } } = await supabase.auth.getSession();
        console.log('Session check:', session ? 'Found' : 'None');

        if (session) {
            currentUser = session.user;
            await loadDashboard();
        } else {
            console.log('Rendering login page...');
            renderLoginPage();
        }
    } catch (error) {
        console.error('Initialization error:', error);
        renderLoginPage();
    }
})();
