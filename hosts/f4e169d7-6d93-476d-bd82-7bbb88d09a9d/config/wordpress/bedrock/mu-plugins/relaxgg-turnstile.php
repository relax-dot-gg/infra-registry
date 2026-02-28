<?php
/**
 * Turnstile config via environment variables.
 */

function relaxgg_turnstile_env(string $key): ?string
{
    $value = getenv($key);
    if ($value !== false && $value !== '') {
        return $value;
    }
    if (isset($_ENV[$key]) && $_ENV[$key] !== '') {
        return $_ENV[$key];
    }
    if (isset($_SERVER[$key]) && $_SERVER[$key] !== '') {
        return $_SERVER[$key];
    }
    return null;
}

$site_key = relaxgg_turnstile_env('CF_TURNSTILE_SITE_KEY');
$secret_key = relaxgg_turnstile_env('CF_TURNSTILE_SECRET_KEY');

if ($site_key && !defined('CF_TURNSTILE_SITE_KEY')) {
    define('CF_TURNSTILE_SITE_KEY', $site_key);
}
if ($secret_key && !defined('CF_TURNSTILE_SECRET_KEY')) {
    define('CF_TURNSTILE_SECRET_KEY', $secret_key);
}
