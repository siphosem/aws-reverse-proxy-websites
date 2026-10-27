CREATE DATABASE IF NOT EXISTS tooling CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tooling;

CREATE TABLE IF NOT EXISTS tools (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80) NOT NULL,
  url VARCHAR(500) NOT NULL,
  category VARCHAR(40) NOT NULL DEFAULT 'Other',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_name (name)
);

INSERT IGNORE INTO tools (name, url, category) VALUES
  ('Jenkins', 'https://www.jenkins.io/doc/', 'CI/CD'),
  ('GitHub Actions', 'https://docs.github.com/actions', 'CI/CD'),
  ('Grafana', 'https://grafana.com/docs/', 'Monitoring'),
  ('Prometheus', 'https://prometheus.io/docs/', 'Monitoring'),
  ('AWS Console', 'https://console.aws.amazon.com/', 'Cloud'),
  ('Terraform Registry', 'https://registry.terraform.io/', 'Cloud');
