<?php
/**
 * Plugin Name: SaralBook App Links
 * Description: Makes https://saralbook.com/app/join/CODE links open the SaralBook app (Android App Links) and shows a small "Open in app / Get it on Google Play" page when the app is not installed.
 * Version: 1.0.0
 * Author: SaralBook
 * License: GPLv2 or later
 *
 * Setup: install and activate, then Settings > SaralBook App Links and paste the
 * SHA-256 fingerprint(s) of the key that signs your APK (see docs/DEEP_LINKS.md).
 * Check: https://saralbook.com/.well-known/assetlinks.json
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

const SARALBOOK_LINKS_OPTION  = 'saralbook_app_links_sha256';
const SARALBOOK_LINKS_PACKAGE = 'com.saralbook.app';

/** Fingerprints typed in settings, one per line, cleaned up. */
function saralbook_links_fingerprints() {
	$out = array();
	foreach ( preg_split( '/[\s,]+/', (string) get_option( SARALBOOK_LINKS_OPTION, '' ) ) as $fp ) {
		$fp = strtoupper( trim( $fp ) );
		if ( preg_match( '/^([0-9A-F]{2}:){31}[0-9A-F]{2}$/', $fp ) ) {
			$out[] = $fp;
		}
	}
	return array_values( array_unique( $out ) );
}

/** Serve /.well-known/assetlinks.json and the /app/join/CODE page. */
add_action(
	'template_redirect',
	function () {
		$path = wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH );
		$path = '/' . trim( (string) $path, '/' );

		if ( '/.well-known/assetlinks.json' === $path ) {
			header( 'Content-Type: application/json; charset=utf-8' );
			header( 'Cache-Control: public, max-age=3600' );
			echo wp_json_encode(
				array(
					array(
						'relation' => array( 'delegate_permission/common.handle_all_urls' ),
						'target'   => array(
							'namespace'                => 'android_app',
							'package_name'             => SARALBOOK_LINKS_PACKAGE,
							'sha256_cert_fingerprints' => saralbook_links_fingerprints(),
						),
					),
				)
			);
			exit;
		}

		if ( preg_match( '#^/app/join/([A-Za-z0-9]{8})$#', $path, $m ) ) {
			$code = strtoupper( $m[1] );
			if ( ! preg_match( '/^[A-HJ-NP-Z2-9]{8}$/', $code ) ) {
				return;
			}
			status_header( 200 );
			nocache_headers();
			header( 'Content-Type: text/html; charset=utf-8' );
			$app   = esc_url( 'saralbook://join/' . $code, array( 'saralbook' ) );
			$store = esc_url( 'https://play.google.com/store/apps/details?id=' . SARALBOOK_LINKS_PACKAGE );
			?>
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>Join a group on SaralBook</title>
<style>
body{font-family:system-ui,sans-serif;background:#f5f7fb;margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center}
.card{background:#fff;border-radius:16px;padding:28px;max-width:360px;margin:16px;text-align:center;box-shadow:0 4px 20px rgba(0,0,0,.08)}
.code{font-size:28px;letter-spacing:4px;font-weight:700;margin:12px 0}
a.b{display:block;padding:14px;border-radius:12px;text-decoration:none;font-weight:600;margin-top:12px}
.p{background:#1a56db;color:#fff}.s{background:#eef2ff;color:#1a56db}
</style></head><body><div class="card">
<h2>You are invited to a group on SaralBook</h2>
<p>सरलबुक ग्रुप में जुड़ने का निमंत्रण</p>
<div class="code"><?php echo esc_html( $code ); ?></div>
<a class="b p" href="<?php echo $app; // phpcs:ignore WordPress.Security.EscapeOutput ?>">Open in app / ऐप में खोलें</a>
<a class="b s" href="<?php echo $store; // phpcs:ignore WordPress.Security.EscapeOutput ?>">Get it on Google Play</a>
<p style="color:#667;font-size:13px">Already installed? Open SaralBook &gt; Group Expenses &gt; Join and type the code.</p>
</div></body></html>
			<?php
			exit;
		}
	},
	0
);

/** Settings page. */
add_action(
	'admin_menu',
	function () {
		add_options_page( 'SaralBook App Links', 'SaralBook App Links', 'manage_options', 'saralbook-app-links', 'saralbook_links_page' );
	}
);

function saralbook_links_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	if ( isset( $_POST['saralbook_links_nonce'] ) && wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['saralbook_links_nonce'] ) ), 'saralbook_links' ) ) {
		update_option( SARALBOOK_LINKS_OPTION, sanitize_textarea_field( wp_unslash( isset( $_POST['fp'] ) ? $_POST['fp'] : '' ) ) );
		echo '<div class="updated"><p>Saved.</p></div>';
	}
	$val = (string) get_option( SARALBOOK_LINKS_OPTION, '' );
	?>
	<div class="wrap"><h1>SaralBook App Links</h1>
	<form method="post">
		<?php wp_nonce_field( 'saralbook_links', 'saralbook_links_nonce' ); ?>
		<p>SHA-256 fingerprint(s) of the key that signs your APK, one per line (format AA:BB:...:FF).</p>
		<textarea name="fp" rows="4" cols="90" class="code"><?php echo esc_textarea( $val ); ?></textarea>
		<p><?php submit_button( 'Save', 'primary', 'submit', false ); ?></p>
	</form>
	<p>Valid fingerprints now: <strong><?php echo (int) count( saralbook_links_fingerprints() ); ?></strong>.
	Check <a href="<?php echo esc_url( home_url( '/.well-known/assetlinks.json' ) ); ?>" target="_blank">assetlinks.json</a>.</p></div>
	<?php
}
