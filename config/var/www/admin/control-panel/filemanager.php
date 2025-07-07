<?php
/**
 * Simple redirect to Tiny File Manager
 * Official TinyFileManager from GitHub repository
 */

// Redirect to the official TinyFileManager installation
header('Location: /tinyfilemanager/'); // codacy:ignore - header() required for redirect functionality in standalone service
exit; // codacy:ignore - exit required for redirect termination in standalone service
?>
