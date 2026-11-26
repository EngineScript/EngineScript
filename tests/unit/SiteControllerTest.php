<?php

/**
 * Tests for GET /sites: reading the WordPress sites from the enabled nginx configurations.
 *
 * The configurations live in a temporary directory (SiteController::useNginxSitesPath()). The
 * controller accepts only a POSIX document root, as on the server, so the version check expects
 * the real version on Linux and "Unknown" elsewhere; parseWordPressVersion() is tested directly.
 */

declare(strict_types=1);

use EngineScript\Dashboard\API\Controllers\SiteController;

final class SiteControllerTest extends EsTestCase
{
    private string $sites;

    protected function setUp(): void
    {
        parent::setUp();
        $this->sites = (string) realpath($this->makeTemporaryDirectory());
        SiteController::useNginxSitesPath($this->sites);
    }

    protected function tearDown(): void
    {
        SiteController::useNginxSitesPath(null);
        parent::tearDown();
    }

    /**
     * Write an nginx configuration into the sites directory.
     */
    private function site(string $name, string $content): void
    {
        file_put_contents($this->sites . '/' . $name, $content);
    }

    /**
     * Create a WordPress document root with a version.php, and return its path.
     */
    private function documentRoot(string $version): string
    {
        $root = (string) realpath($this->makeTemporaryDirectory());
        mkdir($root . '/wp-includes');
        file_put_contents($root . '/wp-includes/version.php', "<?php\n\$wp_version = '{$version}';\n");

        return $root;
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function sites(): array
    {
        $result = $this->respond(fn() => $this->controller(SiteController::class)->getSites());
        $this->assertSame(200, $result['status']);
        $sites = $result['json'];
        usort($sites, static fn(array $a, array $b): int => strcmp((string) $a['domain'], (string) $b['domain']));

        return $sites;
    }

    public function testWordPressSitesAreListedWithTheirDomainVersionAndSsl(): void
    {
        $root = $this->documentRoot('6.8.3');
        $this->site('example.com.conf', "server {\n  server_name example.com www.example.com;\n  ssl_certificate /etc/nginx/ssl/example.com/fullchain.pem;\n  root {$root};\n  include /etc/nginx/globals/wp-secure.conf;\n}\n");
        $this->site('shop.example.conf', "server {\n  server_name shop.example;\n  root /no/such/root;\n  # wordpress\n}\n");

        $sites = $this->sites();

        $this->assertSame(['example.com', 'shop.example'], array_column($sites, 'domain'));
        $this->assertSame(['Enabled', 'Unknown'], array_column($sites, 'ssl_status'));
        $this->assertSame(DIRECTORY_SEPARATOR === '/' ? '6.8.3' : 'Unknown', $sites[0]['wp_version']);
        $this->assertSame('Unknown', $sites[1]['wp_version']);
    }

    public function testOtherConfigurationsAreLeftOut(): void
    {
        $this->site('default', "server { server_name example.org; # wordpress\n}\n");
        $this->site('static.conf', "server {\n  server_name static.example;\n  root /var/www/static;\n}\n");
        $this->site('catchall.conf', "server {\n  server_name _;\n  # wordpress\n}\n");
        $this->site('nameless.conf', "server {\n  root /var/www/x;\n  # wordpress\n}\n");
        $this->site('bad name!', "server { server_name bad.example; # wordpress\n}\n");

        $this->assertSame([], $this->sites());
        $this->assertNotSame([], array_filter($this->logLines(), static fn(string $line): bool => str_contains($line, 'Suspicious nginx config filename')));
    }

    public function testNoSitesDirectoryMeansNoSites(): void
    {
        SiteController::useNginxSitesPath($this->sites . '/missing');

        $this->assertSame([], $this->sites());
    }

    public function testVersionIsReadFromVersionPhp(): void
    {
        $parse = new ReflectionMethod(SiteController::class, 'parseWordPressVersion');
        $controller = $this->controller(SiteController::class);
        $root = $this->documentRoot('7.0-beta2');
        $empty = $this->makeTemporaryDirectory() . '/version.php';
        file_put_contents($empty, "<?php\n// no version here\n");

        $this->assertSame('7.0-beta2', $parse->invoke($controller, $root . '/wp-includes/version.php'));
        $this->assertSame('Unknown', $parse->invoke($controller, $empty));
    }

    public function testVersionFileMustBeInsideTheDocumentRoot(): void
    {
        $validate = new ReflectionMethod(SiteController::class, 'validateWordPressPath');
        $controller = $this->controller(SiteController::class);
        $root = $this->documentRoot('6.8.3');

        $this->assertSame((string) realpath($root . '/wp-includes/version.php'), $validate->invoke($controller, $root));
        $this->assertFalse($validate->invoke($controller, ''));
        $this->assertFalse($validate->invoke($controller, $this->makeTemporaryDirectory()));
    }

    public function testDocumentRootMustBeAPlainAbsolutePath(): void
    {
        $extract = new ReflectionMethod(SiteController::class, 'extractDocumentRoot');
        $controller = $this->controller(SiteController::class);

        $this->assertSame('', $extract->invoke($controller, 'server { }'));
        $this->assertSame('', $extract->invoke($controller, 'root $document_root;'));
        $this->assertSame('', $extract->invoke($controller, 'root /no/such/directory;'));
    }
}
