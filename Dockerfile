# Bindi AI Support Ticket System with Admin Board
# Build: 2026-01-06-v21 - Admin panel + image uploads

FROM php:8.1-apache-bookworm

# MySQL extension + GD for image handling
RUN apt-get update && apt-get install -y libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mysqli gd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Increase upload limits
RUN echo "upload_max_filesize = 10M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size = 12M" >> /usr/local/etc/php/conf.d/uploads.ini

# Apache port 8080
RUN a2enmod rewrite \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

# Create uploads directory
RUN mkdir -p /var/www/html/uploads && chown www-data:www-data /var/www/html/uploads

# Main ticket system
COPY <<'PHPCODE' /var/www/html/index.php
<?php
error_reporting(0);
$db_host = getenv('DB_HOST') ?: 'localhost';
$db_name = getenv('DB_DATABASE') ?: 'tickets';
$db_user = getenv('DB_USERNAME') ?: 'root';
$db_pass = getenv('DB_PASSWORD') ?: '';

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $pdo->exec("CREATE TABLE IF NOT EXISTS tickets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL,
        subject VARCHAR(200) NOT NULL,
        message TEXT NOT NULL,
        image_path VARCHAR(255) DEFAULT NULL,
        status ENUM('open','in_progress','closed') DEFAULT 'open',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )");
    
    // Add image_path column if it doesn't exist (for existing installs)
    try { $pdo->exec("ALTER TABLE tickets ADD COLUMN image_path VARCHAR(255) DEFAULT NULL"); } catch(Exception $e) {}
    try { $pdo->exec("ALTER TABLE tickets ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"); } catch(Exception $e) {}
    try { $pdo->exec("ALTER TABLE tickets MODIFY COLUMN status ENUM('open','in_progress','closed') DEFAULT 'open'"); } catch(Exception $e) {}
    
    $db_ok = true;
} catch(Exception $e) {
    $db_ok = false;
    $db_error = $e->getMessage();
}

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['submit_ticket'])) {
    $name = htmlspecialchars($_POST['name'] ?? '');
    $email = filter_var($_POST['email'] ?? '', FILTER_SANITIZE_EMAIL);
    $subject = htmlspecialchars($_POST['subject'] ?? '');
    $message = htmlspecialchars($_POST['message'] ?? '');
    $image_path = null;
    
    // Handle image upload
    if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        $allowed = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        if (in_array($_FILES['image']['type'], $allowed) && $_FILES['image']['size'] < 10485760) {
            $ext = pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION);
            $filename = uniqid('ticket_') . '.' . $ext;
            $upload_path = '/var/www/html/uploads/' . $filename;
            if (move_uploaded_file($_FILES['image']['tmp_name'], $upload_path)) {
                $image_path = 'uploads/' . $filename;
            }
        }
    }
    
    if ($name && $email && $subject && $message && $db_ok) {
        $stmt = $pdo->prepare("INSERT INTO tickets (name, email, subject, message, image_path) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$name, $email, $subject, $message, $image_path]);
        $ticket_id = $pdo->lastInsertId();
        $msg = '<div class="alert success">Ticket #' . $ticket_id . ' submitted successfully! We will respond to ' . $email . ' soon.</div>';
    } else {
        $msg = '<div class="alert error">Please fill all required fields.</div>';
    }
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Bindi AI Support</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        body { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); margin: 0; padding: 20px; min-height: 100vh; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); }
        h1 { color: #333; margin-top: 0; }
        .logo { font-size: 3em; margin-bottom: 10px; }
        .subtitle { color: #666; margin-bottom: 30px; }
        label { display: block; margin-top: 20px; font-weight: 600; color: #444; }
        input, textarea { width: 100%; padding: 14px; margin-top: 8px; border: 2px solid #e0e0e0; border-radius: 8px; font-size: 16px; transition: border-color 0.3s; }
        input:focus, textarea:focus { border-color: #667eea; outline: none; }
        textarea { height: 150px; resize: vertical; }
        .file-input { border: 2px dashed #e0e0e0; padding: 20px; text-align: center; border-radius: 8px; cursor: pointer; margin-top: 8px; }
        .file-input:hover { border-color: #667eea; background: #f8f9ff; }
        .file-input input { display: none; }
        button { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 16px 32px; border: none; border-radius: 8px; cursor: pointer; font-size: 16px; font-weight: 600; margin-top: 25px; width: 100%; transition: transform 0.2s, box-shadow 0.2s; }
        button:hover { transform: translateY(-2px); box-shadow: 0 5px 20px rgba(102,126,234,0.4); }
        .status { padding: 12px 16px; background: #d4edda; border-radius: 8px; margin-bottom: 20px; display: flex; align-items: center; gap: 10px; }
        .status.error { background: #f8d7da; }
        .alert { padding: 16px; border-radius: 8px; margin-bottom: 20px; }
        .alert.success { background: #d4edda; color: #155724; }
        .alert.error { background: #f8d7da; color: #721c24; }
        .admin-link { text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; }
        .admin-link a { color: #667eea; text-decoration: none; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🤖</div>
        <h1>Bindi AI Support</h1>
        <p class="subtitle">How can we help you today?</p>
        
        <div class="status <?= $db_ok ? '' : 'error' ?>">
            <?= $db_ok ? '✅ System Ready' : '⚠️ ' . htmlspecialchars($db_error) ?>
        </div>
        
        <?= $msg ?>
        
        <form method="POST" enctype="multipart/form-data">
            <label>Your Name *</label>
            <input type="text" name="name" required placeholder="John Smith">
            
            <label>Email Address *</label>
            <input type="email" name="email" required placeholder="john@example.com">
            
            <label>Subject *</label>
            <input type="text" name="subject" required placeholder="Brief description of your issue">
            
            <label>How can we help? *</label>
            <textarea name="message" required placeholder="Please describe your issue in detail..."></textarea>
            
            <label>Attach Screenshot (optional)</label>
            <div class="file-input" onclick="document.getElementById('image').click()">
                <span id="file-label">📎 Click to upload image (max 10MB)</span>
                <input type="file" name="image" id="image" accept="image/*" onchange="document.getElementById('file-label').textContent = this.files[0]?.name || '📎 Click to upload image'">
            </div>
            
            <button type="submit" name="submit_ticket">Submit Support Request</button>
        </form>
        
        <div class="admin-link">
            <a href="/admin.php">🔐 Staff Login</a>
        </div>
    </div>
</body>
</html>
PHPCODE

# Admin panel with board view
COPY <<'ADMINCODE' /var/www/html/admin.php
<?php
session_start();
error_reporting(0);

$db_host = getenv('DB_HOST') ?: 'localhost';
$db_name = getenv('DB_DATABASE') ?: 'tickets';
$db_user = getenv('DB_USERNAME') ?: 'root';
$db_pass = getenv('DB_PASSWORD') ?: '';
$admin_pass = getenv('ADMIN_PASSWORD') ?: 'BindiAdmin2025';

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db_ok = true;
} catch(Exception $e) {
    $db_ok = false;
    die("Database error: " . $e->getMessage());
}

// Handle login
if (isset($_POST['login'])) {
    if ($_POST['password'] === $admin_pass) {
        $_SESSION['admin'] = true;
    }
}

// Handle logout
if (isset($_GET['logout'])) {
    unset($_SESSION['admin']);
    header('Location: admin.php');
    exit;
}

// Handle status update
if (isset($_POST['update_status']) && isset($_SESSION['admin'])) {
    $stmt = $pdo->prepare("UPDATE tickets SET status = ? WHERE id = ?");
    $stmt->execute([$_POST['status'], $_POST['ticket_id']]);
    header('Location: admin.php');
    exit;
}

// Handle delete
if (isset($_POST['delete_ticket']) && isset($_SESSION['admin'])) {
    $stmt = $pdo->prepare("DELETE FROM tickets WHERE id = ?");
    $stmt->execute([$_POST['ticket_id']]);
    header('Location: admin.php');
    exit;
}

// Get tickets by status
$open = $pdo->query("SELECT * FROM tickets WHERE status = 'open' ORDER BY created_at DESC")->fetchAll(PDO::FETCH_ASSOC);
$in_progress = $pdo->query("SELECT * FROM tickets WHERE status = 'in_progress' ORDER BY created_at DESC")->fetchAll(PDO::FETCH_ASSOC);
$closed = $pdo->query("SELECT * FROM tickets WHERE status = 'closed' ORDER BY updated_at DESC")->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html>
<head>
    <title>Bindi AI Support - Admin</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; }
        body { background: #1a1a2e; color: #eee; min-height: 100vh; }
        .login-container { max-width: 400px; margin: 100px auto; padding: 40px; background: #16213e; border-radius: 16px; }
        .login-container h1 { margin-bottom: 30px; }
        .login-container input { width: 100%; padding: 14px; margin-bottom: 20px; border: none; border-radius: 8px; font-size: 16px; }
        .login-container button { width: 100%; padding: 14px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border: none; border-radius: 8px; color: white; font-size: 16px; cursor: pointer; }
        
        .header { background: #16213e; padding: 20px 30px; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { font-size: 1.5em; }
        .header a { color: #667eea; text-decoration: none; }
        
        .board { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; padding: 30px; min-height: calc(100vh - 80px); }
        @media (max-width: 900px) { .board { grid-template-columns: 1fr; } }
        
        .column { background: #16213e; border-radius: 12px; padding: 20px; }
        .column-header { font-weight: 600; padding-bottom: 15px; border-bottom: 2px solid #0f3460; margin-bottom: 15px; display: flex; justify-content: space-between; align-items: center; }
        .column-header .count { background: #0f3460; padding: 4px 12px; border-radius: 20px; font-size: 14px; }
        
        .ticket { background: #0f3460; border-radius: 10px; padding: 16px; margin-bottom: 12px; cursor: pointer; transition: transform 0.2s; }
        .ticket:hover { transform: translateY(-2px); }
        .ticket-id { font-size: 12px; color: #667eea; margin-bottom: 8px; }
        .ticket-subject { font-weight: 600; margin-bottom: 8px; }
        .ticket-meta { font-size: 13px; color: #888; margin-bottom: 10px; }
        .ticket-message { font-size: 14px; color: #aaa; margin-bottom: 12px; max-height: 60px; overflow: hidden; }
        .ticket-image { width: 100%; border-radius: 6px; margin-bottom: 10px; max-height: 150px; object-fit: cover; }
        .ticket-actions { display: flex; gap: 8px; flex-wrap: wrap; }
        .ticket-actions button, .ticket-actions select { padding: 8px 12px; border: none; border-radius: 6px; font-size: 13px; cursor: pointer; }
        .btn-progress { background: #f39c12; color: white; }
        .btn-done { background: #27ae60; color: white; }
        .btn-reopen { background: #3498db; color: white; }
        .btn-delete { background: #e74c3c; color: white; }
        
        .open .column-header { color: #e74c3c; border-color: #e74c3c; }
        .progress .column-header { color: #f39c12; border-color: #f39c12; }
        .done .column-header { color: #27ae60; border-color: #27ae60; }
        
        .modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); z-index: 100; align-items: center; justify-content: center; }
        .modal.active { display: flex; }
        .modal-content { background: #16213e; padding: 30px; border-radius: 16px; max-width: 600px; width: 90%; max-height: 80vh; overflow-y: auto; }
        .modal-close { float: right; font-size: 24px; cursor: pointer; color: #888; }
        .modal h2 { margin-bottom: 20px; }
        .modal p { margin-bottom: 15px; line-height: 1.6; }
        .modal img { max-width: 100%; border-radius: 8px; margin-top: 15px; }
    </style>
</head>
<body>

<?php if (!isset($_SESSION['admin'])): ?>
<div class="login-container">
    <h1>🔐 Staff Login</h1>
    <form method="POST">
        <input type="password" name="password" placeholder="Enter admin password" required>
        <button type="submit" name="login">Login</button>
    </form>
    <p style="margin-top:20px;text-align:center;"><a href="/" style="color:#667eea;">← Back to support form</a></p>
</div>
<?php else: ?>

<div class="header">
    <h1>🤖 Bindi AI Support Board</h1>
    <div>
        <a href="/">← Public Form</a> &nbsp;|&nbsp;
        <a href="?logout">Logout</a>
    </div>
</div>

<div class="board">
    <div class="column open">
        <div class="column-header">
            🔴 Open <span class="count"><?= count($open) ?></span>
        </div>
        <?php foreach($open as $t): ?>
        <div class="ticket" onclick="showModal(<?= htmlspecialchars(json_encode($t)) ?>)">
            <div class="ticket-id">#<?= $t['id'] ?></div>
            <div class="ticket-subject"><?= htmlspecialchars($t['subject']) ?></div>
            <div class="ticket-meta"><?= htmlspecialchars($t['name']) ?> • <?= date('M j, g:ia', strtotime($t['created_at'])) ?></div>
            <?php if($t['image_path']): ?><img src="/<?= $t['image_path'] ?>" class="ticket-image"><?php endif; ?>
            <div class="ticket-message"><?= htmlspecialchars($t['message']) ?></div>
            <div class="ticket-actions" onclick="event.stopPropagation()">
                <form method="POST" style="display:inline">
                    <input type="hidden" name="ticket_id" value="<?= $t['id'] ?>">
                    <input type="hidden" name="status" value="in_progress">
                    <button type="submit" name="update_status" class="btn-progress">→ In Progress</button>
                </form>
                <form method="POST" style="display:inline">
                    <input type="hidden" name="ticket_id" value="<?= $t['id'] ?>">
                    <input type="hidden" name="status" value="closed">
                    <button type="submit" name="update_status" class="btn-done">✓ Done</button>
                </form>
            </div>
        </div>
        <?php endforeach; ?>
        <?php if(empty($open)): ?><p style="color:#666;text-align:center;padding:20px;">No open tickets 🎉</p><?php endif; ?>
    </div>
    
    <div class="column progress">
        <div class="column-header">
            🟡 In Progress <span class="count"><?= count($in_progress) ?></span>
        </div>
        <?php foreach($in_progress as $t): ?>
        <div class="ticket" onclick="showModal(<?= htmlspecialchars(json_encode($t)) ?>)">
            <div class="ticket-id">#<?= $t['id'] ?></div>
            <div class="ticket-subject"><?= htmlspecialchars($t['subject']) ?></div>
            <div class="ticket-meta"><?= htmlspecialchars($t['name']) ?> • <?= date('M j, g:ia', strtotime($t['created_at'])) ?></div>
            <?php if($t['image_path']): ?><img src="/<?= $t['image_path'] ?>" class="ticket-image"><?php endif; ?>
            <div class="ticket-message"><?= htmlspecialchars($t['message']) ?></div>
            <div class="ticket-actions" onclick="event.stopPropagation()">
                <form method="POST" style="display:inline">
                    <input type="hidden" name="ticket_id" value="<?= $t['id'] ?>">
                    <input type="hidden" name="status" value="open">
                    <button type="submit" name="update_status" class="btn-reopen">← Reopen</button>
                </form>
                <form method="POST" style="display:inline">
                    <input type="hidden" name="ticket_id" value="<?= $t['id'] ?>">
                    <input type="hidden" name="status" value="closed">
                    <button type="submit" name="update_status" class="btn-done">✓ Done</button>
                </form>
            </div>
        </div>
        <?php endforeach; ?>
        <?php if(empty($in_progress)): ?><p style="color:#666;text-align:center;padding:20px;">Nothing in progress</p><?php endif; ?>
    </div>
    
    <div class="column done">
        <div class="column-header">
            🟢 Completed <span class="count"><?= count($closed) ?></span>
        </div>
        <?php foreach($closed as $t): ?>
        <div class="ticket" onclick="showModal(<?= htmlspecialchars(json_encode($t)) ?>)">
            <div class="ticket-id">#<?= $t['id'] ?></div>
            <div class="ticket-subject"><?= htmlspecialchars($t['subject']) ?></div>
            <div class="ticket-meta"><?= htmlspecialchars($t['name']) ?> • <?= date('M j', strtotime($t['created_at'])) ?></div>
            <div class="ticket-actions" onclick="event.stopPropagation()">
                <form method="POST" style="display:inline">
                    <input type="hidden" name="ticket_id" value="<?= $t['id'] ?>">
                    <input type="hidden" name="status" value="open">
                    <button type="submit" name="update_status" class="btn-reopen">← Reopen</button>
                </form>
                <form method="POST" style="display:inline" onsubmit="return confirm('Delete this ticket?')">
                    <input type="hidden" name="ticket_id" value="<?= $t['id'] ?>">
                    <button type="submit" name="delete_ticket" class="btn-delete">🗑</button>
                </form>
            </div>
        </div>
        <?php endforeach; ?>
        <?php if(empty($closed)): ?><p style="color:#666;text-align:center;padding:20px;">No completed tickets</p><?php endif; ?>
    </div>
</div>

<div class="modal" id="ticketModal" onclick="if(event.target===this)this.classList.remove('active')">
    <div class="modal-content">
        <span class="modal-close" onclick="document.getElementById('ticketModal').classList.remove('active')">&times;</span>
        <h2 id="modal-subject"></h2>
        <p><strong>From:</strong> <span id="modal-name"></span> (<span id="modal-email"></span>)</p>
        <p><strong>Submitted:</strong> <span id="modal-date"></span></p>
        <p><strong>Message:</strong></p>
        <p id="modal-message" style="background:#0f3460;padding:15px;border-radius:8px;"></p>
        <img id="modal-image" style="display:none;">
    </div>
</div>

<script>
function showModal(ticket) {
    document.getElementById('modal-subject').textContent = '#' + ticket.id + ' - ' + ticket.subject;
    document.getElementById('modal-name').textContent = ticket.name;
    document.getElementById('modal-email').textContent = ticket.email;
    document.getElementById('modal-date').textContent = ticket.created_at;
    document.getElementById('modal-message').textContent = ticket.message;
    const img = document.getElementById('modal-image');
    if (ticket.image_path) {
        img.src = '/' + ticket.image_path;
        img.style.display = 'block';
    } else {
        img.style.display = 'none';
    }
    document.getElementById('ticketModal').classList.add('active');
}
</script>

<?php endif; ?>

</body>
</html>
ADMINCODE

RUN chown -R www-data:www-data /var/www/html

EXPOSE 8080
CMD ["apache2-foreground"]
