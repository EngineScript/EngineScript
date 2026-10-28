<?php

/**
 * EngineScript - send one FastCGI request straight to a PHP-FPM socket
 *
 * Usage: php php-fpm-check.php /run/php/php8.5-fpm.sock /path/to/script.php
 *
 * Prints the response body of the script, and exits with 0 when PHP-FPM completed the request
 * (also when the script failed, so callers check the body). Used by php_fpm_answers() in
 * enginescript-common.sh to check that PHP-FPM serves PHP without going through Nginx, a site,
 * or the FastCGI cache.
 *
 * @license GPL-3.0
 */

declare(strict_types=1);

// unpack() format codes below: cspell:ignore Cversion nlength Cpadding Creserved Nstatus

const FCGI_VERSION = 1;
const FCGI_BEGIN_REQUEST = 1;
const FCGI_END_REQUEST = 3;
const FCGI_PARAMS = 4;
const FCGI_STDIN = 5;
const FCGI_STDOUT = 6;
const FCGI_RESPONDER = 1;

/**
 * Build one FastCGI record (request ID 1)
 */
function fcgiRecord(int $type, string $content): string
{
    return pack('CCnnCx', FCGI_VERSION, $type, 1, strlen($content), 0) . $content;
}

/**
 * Encode a FastCGI name or value length (one byte below 128, otherwise four)
 *
 * @param int<0, max> $size
 */
function fcgiLength(int $size): string
{
    return $size < 128 ? chr($size) : pack('N', $size | 0x80000000);
}

/**
 * Encode one FastCGI name-value pair
 */
function fcgiPair(string $name, string $value): string
{
    return fcgiLength(strlen($name)) . fcgiLength(strlen($value)) . $name . $value;
}

/**
 * Read exactly $size bytes, or fewer if the connection closes
 *
 * @param resource $stream
 */
function readBytes($stream, int $size): string
{
    $data = '';
    while (strlen($data) < $size && !feof($stream)) {
        $chunk = fread($stream, max(1, $size - strlen($data)));
        if ($chunk === false || $chunk === '') {
            break;
        }
        $data .= $chunk;
    }

    return $data;
}

$socketPath = $argv[1] ?? '';
$scriptPath = $argv[2] ?? '';
if ($socketPath === '' || $scriptPath === '') {
    fwrite(STDERR, "Usage: php php-fpm-check.php <php-fpm socket> <script>\n");
    exit(2);
}

$errorCode = 0;
$errorMessage = '';
// The error is reported below; suppress PHP's own warning so it is not printed twice
$stream = @stream_socket_client('unix://' . $socketPath, $errorCode, $errorMessage, 5);
if ($stream === false) {
    fwrite(STDERR, "Could not connect to {$socketPath}: {$errorMessage}\n");
    exit(2);
}
stream_set_timeout($stream, 10);

$params = [
    'GATEWAY_INTERFACE' => 'FastCGI/1.0',
    'REQUEST_METHOD' => 'GET',
    'SCRIPT_FILENAME' => $scriptPath,
    'SCRIPT_NAME' => '/' . basename($scriptPath),
    'REQUEST_URI' => '/' . basename($scriptPath),
    'QUERY_STRING' => '',
    'SERVER_PROTOCOL' => 'HTTP/1.1',
    'SERVER_NAME' => 'localhost',
    'SERVER_PORT' => '80',
    'REMOTE_ADDR' => '127.0.0.1',
    'CONTENT_LENGTH' => '0',
];
$encodedParams = '';
foreach ($params as $name => $value) {
    $encodedParams .= fcgiPair($name, $value);
}

fwrite(
    $stream,
    fcgiRecord(FCGI_BEGIN_REQUEST, pack('nCx5', FCGI_RESPONDER, 0))
    . fcgiRecord(FCGI_PARAMS, $encodedParams)
    . fcgiRecord(FCGI_PARAMS, '')
    . fcgiRecord(FCGI_STDIN, '')
);

$output = '';
$appStatus = null;
while (!feof($stream)) {
    $header = readBytes($stream, 8);
    if (strlen($header) < 8) {
        break;
    }
    /** @var array{type: int, length: int, padding: int} $record */
    $record = unpack('Cversion/Ctype/nid/nlength/Cpadding/Creserved', $header);
    $content = $record['length'] > 0 ? readBytes($stream, $record['length']) : '';
    if ($record['padding'] > 0) {
        readBytes($stream, $record['padding']);
    }
    if ($record['type'] === FCGI_STDOUT) {
        $output .= $content;
    } elseif ($record['type'] === FCGI_END_REQUEST) {
        /** @var array{status: int} $end */
        $end = unpack('Nstatus', $content);
        $appStatus = $end['status'];
        break;
    }
}
fclose($stream);

// Drop the CGI headers (Content-type, X-Powered-By, ...) and print the body
$bodyStart = strpos($output, "\r\n\r\n");
echo $bodyStart === false ? $output : substr($output, $bodyStart + 4);

exit($appStatus === 0 ? 0 : 1);
