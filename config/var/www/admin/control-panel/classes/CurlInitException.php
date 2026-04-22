<?php
/**
 * EngineScript Admin Dashboard - CurlInitException
 *
 * Thrown when curl_init() fails, indicating the cURL PHP extension is
 * unavailable or the system has exhausted handle resources.
 *
 * @package EngineScript\Dashboard\Exceptions
 */

/**
 * Exception thrown when curl_init() returns false.
 *
 * Extends \RuntimeException so existing catch (\RuntimeException $e) blocks
 * continue to catch this without modification.
 */
final class CurlInitException extends \RuntimeException {}
