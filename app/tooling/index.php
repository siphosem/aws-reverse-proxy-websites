<?php
// Tooling: the DevOps team's internal link board, backed by RDS MySQL.
declare(strict_types=1);

$config = require getenv('TOOLING_CONFIG') ?: '/etc/tooling/db.php';

function db(array $c): mysqli
{
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    $db = new mysqli($c['host'], $c['user'], $c['password'], $c['name']);
    $db->set_charset('utf8mb4');
    return $db;
}

function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

$error = '';
$db = null;
try {
    $db = db($config);
} catch (mysqli_sql_exception $ex) {
    http_response_code(503);
    $error = 'Database unavailable.';
}

if ($db && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = trim((string)($_POST['name'] ?? ''));
    $url = trim((string)($_POST['url'] ?? ''));
    $category = trim((string)($_POST['category'] ?? 'Other'));
    $valid = $name !== '' && strlen($name) <= 80
        && filter_var($url, FILTER_VALIDATE_URL)
        && preg_match('#^https?://#i', $url);
    if ($valid) {
        // Prepared statement: no SQL injection.
        $stmt = $db->prepare('INSERT INTO tools (name, url, category) VALUES (?, ?, ?)');
        $stmt->bind_param('sss', $name, $url, $category);
        $stmt->execute();
        header('Location: /', true, 303);
        exit;
    }
    $error = 'Enter a name (max 80 characters) and a full http(s) URL.';
}

$tools = [];
if ($db) {
    $res = $db->query('SELECT name, url, category FROM tools ORDER BY category, name');
    $tools = $res->fetch_all(MYSQLI_ASSOC);
}
$categories = ['CI/CD', 'Monitoring', 'Cloud', 'Code', 'Other'];
$host = gethostname() ?: 'unknown';
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Tooling</title>
  <style>
    :root { --bg: #f5f6f8; --card: #fff; --text: #1d2125; --muted: #66707a; --accent: #0f766e; }
    body { margin: 0; font-family: system-ui, sans-serif; background: var(--bg); color: var(--text); }
    main { max-width: 760px; margin: 40px auto; padding: 0 16px; }
    h1 { margin: 0; }
    .sub { color: var(--muted); margin: 4px 0 24px; font-size: .9rem; }
    table { width: 100%; border-collapse: collapse; background: var(--card); border-radius: 8px; overflow: hidden; }
    th, td { text-align: left; padding: 10px 14px; border-bottom: 1px solid #e6e8eb; }
    th { font-size: .8rem; text-transform: uppercase; color: var(--muted); }
    a { color: var(--accent); }
    form { display: flex; flex-wrap: wrap; gap: 8px; margin: 24px 0 8px; }
    input, select { padding: 8px 10px; border: 1px solid #cfd4d9; border-radius: 6px; font-size: .95rem; }
    input[name=url] { flex: 1; min-width: 200px; }
    button { padding: 8px 16px; border: 0; border-radius: 6px; background: var(--accent); color: #fff; cursor: pointer; }
    .error { color: #b42318; }
    footer { color: var(--muted); font-size: .8rem; margin-top: 24px; }
  </style>
</head>
<body>
<main>
  <h1>Tooling</h1>
  <p class="sub">Links the DevOps team uses every day.</p>
  <?php if ($error): ?><p class="error" role="alert"><?= e($error) ?></p><?php endif; ?>
  <table>
    <thead><tr><th>Tool</th><th>Category</th></tr></thead>
    <tbody>
    <?php foreach ($tools as $t): ?>
      <tr>
        <td><a href="<?= e($t['url']) ?>" rel="noopener" target="_blank"><?= e($t['name']) ?></a></td>
        <td><?= e($t['category']) ?></td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$tools): ?><tr><td colspan="2">No tools yet.</td></tr><?php endif; ?>
    </tbody>
  </table>
  <form method="post">
    <input name="name" placeholder="Name" maxlength="80" required aria-label="Tool name">
    <input name="url" type="url" placeholder="https://..." required aria-label="Tool URL">
    <select name="category" aria-label="Category">
      <?php foreach ($categories as $c): ?><option><?= e($c) ?></option><?php endforeach; ?>
    </select>
    <button type="submit">Add</button>
  </form>
  <footer>Served by <?= e($host) ?></footer>
</main>
</body>
</html>
