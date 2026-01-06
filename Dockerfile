# Bindi AI Simple Ticket System
# Build: 2026-01-06-v20 - Custom minimal ticket form

FROM php:8.1-apache-bookworm

# MySQL extension
RUN docker-php-ext-install pdo_mysql mysqli

# Apache port 8080
RUN a2enmod rewrite \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

# Create simple ticket system
COPY <<'PHPCODE' /var/www/html/index.php
<?php
error_reporting(0);
$db_host = getenv('DB_HOST') ?: 'localhost';
$db_name = getenv('DB_DATABASE') ?: 'tickets';
$db_user = getenv('DB_USERNAME') ?: 'root';
$db_pass = getenv('DB_PASSWORD') ?: '';
$app_url = getenv('APP_URL') ?: 'http://localhost:8080';

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Create table if not exists
    $pdo->exec("CREATE TABLE IF NOT EXISTS tickets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL,
        subject VARCHAR(200) NOT NULL,
        message TEXT NOT NULL,
        status ENUM('open','closed') DEFAULT 'open',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    $db_ok = true;
} catch(Exception $e) {
    $db_ok = false;
    $db_error = $e->getMessage();
}

// Handle form submission
$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['submit_ticket'])) {
    $name = htmlspecialchars($_POST['name'] ?? '');
    $email = filter_var($_POST['email'] ?? '', FILTER_SANITIZE_EMAIL);
    $subject = htmlspecialchars($_POST['subject'] ?? '');
    $message = htmlspecialchars($_POST['message'] ?? '');

    if ($name && $email && $subject && $message && $db_ok) {
        $stmt = $pdo->prepare("INSERT INTO tickets (name, email, subject, message) VALUES (?, ?, ?, ?)");
        $stmt->execute([$name, $email, $subject, $message]);
        $msg = '<div style="background:#d4edda;padding:15px;border-radius:5px;margin-bottom:20px;">Ticket submitted successfully! We will respond to ' . $email . ' soon.</div>';
    } else {
        $msg = '<div style="background:#f8d7da;padding:15px;border-radius:5px;margin-bottom:20px;">Please fill all fields.</div>';
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
        body { background: #f5f5f5; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; margin-top: 0; }
        .logo { font-size: 2em; margin-bottom: 10px; }
        label { display: block; margin-top: 15px; font-weight: 600; color: #555; }
        input, textarea { width: 100%; padding: 12px; margin-top: 5px; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
        textarea { height: 150px; resize: vertical; }
        button { background: #007bff; color: white; padding: 15px 30px; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; margin-top: 20px; width: 100%; }
        button:hover { background: #0056b3; }
        .status { padding: 10px; background: <?= $db_ok ? '#d4edda' : '#f8d7da' ?>; border-radius: 5px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🤖</div>
        <h1>Bindi AI Support</h1>
        <div class="status">
            <?php if ($db_ok): ?>
                ✅ System Ready
            <?php else: ?>
                ⚠️ Database: <?= htmlspecialchars($db_error) ?>
            <?php endif; ?>
        </div>
        <?= $msg ?>
        <form method="POST">
            <label>Your Name</label>
            <input type="text" name="name" required>

            <label>Email Address</label>
            <input type="email" name="email" required>

            <label>Subject</label>
            <input type="text" name="subject" required>

            <label>How can we help?</label>
            <textarea name="message" required></textarea>

            <button type="submit" name="submit_ticket">Submit Support Request</button>
        </form>
    </div>
</body>
</html>
PHPCODE

RUN chown -R www-data:www-data /var/www/html

EXPOSE 8080
CMD ["apache2-foreground"]
