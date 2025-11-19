#!/usr/bin/env node
/**
 * Update Dashboard Version Script
 * Updates version strings across all dashboard files
 * 
 * Usage: node update-version.js [new-version]
 * Example: node update-version.js 2025.11.19.03
 * 
 * If no version provided, increments the build number automatically
 */

const fs = require('fs');
const path = require('path');

// Files to update with their version patterns
const FILES_TO_UPDATE = [
    {
        path: 'version.js',
        pattern: /export const DASHBOARD_VERSION = '[\d.]+';/,
        replacement: (ver) => `export const DASHBOARD_VERSION = '${ver}';`
    },
    {
        path: 'dashboard.js',
        patterns: [
            /\/modules\/api\.js\?v=[\d.]+/g,
            /\/modules\/state\.js\?v=[\d.]+/g,
            /\/modules\/charts\.js\?v=[\d.]+/g,
            /\/modules\/utils\.js\?v=[\d.]+/g
        ],
        replacement: (ver) => (match) => match.replace(/v=[\d.]+/, `v=${ver}`)
    },
    {
        path: 'external-services/external-services.js',
        patterns: [
            /\/modules\/utils\.js\?v=[\d.]+/g,
            /\/services-config\.js\?v=[\d.]+/g
        ],
        replacement: (ver) => (match) => match.replace(/v=[\d.]+/, `v=${ver}`)
    }
];

// Get current version from version.js
function getCurrentVersion() {
    const versionFile = fs.readFileSync('version.js', 'utf8');
    const match = versionFile.match(/export const DASHBOARD_VERSION = '([\d.]+)';/);
    return match ? match[1] : null;
}

// Increment build number
function incrementVersion(version) {
    const parts = version.split('.');
    parts[3] = String(parseInt(parts[3]) + 1).padStart(2, '0');
    return parts.join('.');
}

// Update files
function updateFiles(newVersion) {
    let updatedCount = 0;
    
    FILES_TO_UPDATE.forEach(file => {
        const filePath = file.path;
        if (!fs.existsSync(filePath)) {
            console.log(`⚠️  Skipping ${filePath} (not found)`);
            return;
        }
        
        let content = fs.readFileSync(filePath, 'utf8');
        let modified = false;
        
        if (file.pattern) {
            // Single pattern replacement
            const newContent = content.replace(file.pattern, file.replacement(newVersion));
            if (newContent !== content) {
                content = newContent;
                modified = true;
            }
        } else if (file.patterns) {
            // Multiple pattern replacements
            file.patterns.forEach(pattern => {
                const newContent = content.replace(pattern, file.replacement(newVersion));
                if (newContent !== content) {
                    content = newContent;
                    modified = true;
                }
            });
        }
        
        if (modified) {
            fs.writeFileSync(filePath, content, 'utf8');
            console.log(`✅ Updated ${filePath}`);
            updatedCount++;
        } else {
            console.log(`⏭️  No changes in ${filePath}`);
        }
    });
    
    return updatedCount;
}

// Main
function main() {
    const currentVersion = getCurrentVersion();
    if (!currentVersion) {
        console.error('❌ Could not read current version from version.js');
        process.exit(1);
    }
    
    const newVersion = process.argv[2] || incrementVersion(currentVersion);
    
    console.log(`\n📦 Dashboard Version Updater`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`Current version: ${currentVersion}`);
    console.log(`New version:     ${newVersion}`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);
    
    const updated = updateFiles(newVersion);
    
    console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`✨ Updated ${updated} file(s)`);
    console.log(`New version: ${newVersion}\n`);
}

main();
