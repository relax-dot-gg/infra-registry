<?php

if (!defined('ABSPATH')) {
    return;
}

function relaxgg_fluent_smtp_bootstrap(): void
{
    $host = getenv('FLUENTSMTP_HOST') ?: '';
    $port = getenv('FLUENTSMTP_PORT') ?: '587';
    $username = getenv('FLUENTSMTP_USERNAME') ?: '';
    $password = getenv('FLUENTSMTP_PASSWORD') ?: '';
    $from_email = getenv('FLUENTSMTP_FROM_EMAIL') ?: get_option('admin_email');
    $from_name = getenv('FLUENTSMTP_FROM_NAME') ?: get_bloginfo('name');
    $encryption = getenv('FLUENTSMTP_ENCRYPTION') ?: 'tls';
    $auth = getenv('FLUENTSMTP_AUTH') ?: 'yes';
    $auto_tls = getenv('FLUENTSMTP_AUTO_TLS') ?: 'yes';

    if (!$host) {
        return;
    }

    if ($username && !defined('FLUENTMAIL_SMTP_USERNAME')) {
        define('FLUENTMAIL_SMTP_USERNAME', $username);
    }
    if ($password && !defined('FLUENTMAIL_SMTP_PASSWORD')) {
        define('FLUENTMAIL_SMTP_PASSWORD', $password);
    }

    $key_store = ($username && $password) ? 'wp_config' : 'db';

    $connection = [
        'provider' => 'smtp',
        'sender_name' => $from_name,
        'sender_email' => $from_email,
        'force_from_name' => 'yes',
        'force_from_email' => 'yes',
        'return_path' => 'yes',
        'host' => $host,
        'port' => $port,
        'auth' => $auth,
        'username' => $key_store === 'db' ? $username : '',
        'password' => $key_store === 'db' ? $password : '',
        'auto_tls' => $auto_tls,
        'encryption' => $encryption,
        'key_store' => $key_store,
    ];

    $key = md5($from_email);
    $settings = [
        'connections' => [
            $key => [
                'title' => 'SMTP server',
                'provider_settings' => $connection,
            ],
        ],
        'mappings' => [
            $from_email => $key,
        ],
        'misc' => [
            'default_connection' => $key,
            'fallback_connection' => '',
            'log_emails' => 'no',
            'log_saved_interval_days' => '14',
            'disable_fluentcrm_logs' => 'no',
        ],
    ];

    $current = get_option('fluentmail-settings', []);
    if ($current != $settings) {
        update_option('fluentmail-settings', $settings, false);
    }

    $plugin = 'fluent-smtp/fluent-smtp.php';
    $active = get_option('active_plugins', []);
    if (!in_array($plugin, $active, true)) {
        $active[] = $plugin;
        update_option('active_plugins', $active, false);
    }
}

function relaxgg_fluent_smtp_register_email_test(): void
{
    register_rest_route('relaxgg/v1', '/email-test', [
        'methods' => ['GET', 'POST'],
        'permission_callback' => '__return_true',
        'callback' => function () {
            $to = getenv('FLUENTSMTP_TEST_TO') ?: get_option('admin_email');
            $token = bin2hex(random_bytes(16));
            $subject = 'gatus-email-check ' . $token;
            $body = 'gatus email check token=' . $token;
            $sent = wp_mail($to, $subject, $body);
            if (!$sent) {
                return new WP_Error('email_send_failed', 'wp_mail failed', ['status' => 500]);
            }
            return [
                'status' => 'ok',
                'token' => $token,
            ];
        },
    ]);
}

add_action('init', 'relaxgg_fluent_smtp_bootstrap');
add_action('rest_api_init', 'relaxgg_fluent_smtp_register_email_test');
