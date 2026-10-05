<?php
/**
 * Plugin Name: SaralBook App Config
 * Description: Controls the SaralBook mobile app (Home sections, announcements, maintenance, service on/off) from the WordPress dashboard. No app update needed.
 * Version: 1.0.0
 * Author: SaralBook
 * License: GPLv2 or later
 *
 * Install on https://saralbook.com (the address is set in the app in lib/config/endpoints.dart).
 * Public address of the settings: https://saralbook.com/wp-json/saralbook/v1/config
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

const SARALBOOK_APP_OPTION = 'saralbook_app_config';

/** Websites the app knows. Keys must match the ids inside the app. */
function saralbook_app_services() {
	return array(
		'examjobalert'  => 'Exam Job Alert',
		'saralbook'     => 'SaralBook',
		'saralbooktest' => 'SaralBook Test (mock tests)',
		'saralbookstore' => 'SaralBook Store',
		'onlinecalcy'   => 'Online Calcy',
	);
}

/** Domains the app accepts (it ignores any other address for safety). */
function saralbook_app_allowed_url( $url ) {
	$url = esc_url_raw( trim( (string) $url ), array( 'https' ) );
	if ( '' === $url ) {
		return '';
	}
	$host = strtolower( (string) wp_parse_url( $url, PHP_URL_HOST ) );
	foreach ( array( 'saralbook.com', 'examjobalert.com', 'onlinecalcy.com' ) as $domain ) {
		if ( $host === $domain || substr( $host, -strlen( $domain ) - 1 ) === '.' . $domain ) {
			return $url;
		}
	}
	return '';
}

/* ---------- Settings page ---------- */

add_action( 'admin_menu', function () {
	add_menu_page( 'SaralBook App', 'SaralBook App', 'manage_options', 'saralbook-app', 'saralbook_app_render_page', 'dashicons-smartphone', 80 );
} );

add_action( 'admin_init', function () {
	register_setting( 'saralbook_app', SARALBOOK_APP_OPTION, array( 'sanitize_callback' => 'saralbook_app_sanitize' ) );
} );

function saralbook_app_sanitize( $in ) {
	$in  = is_array( $in ) ? $in : array();
	$out = array();

	$out['maintenance'] = array(
		'enabled'  => ! empty( $in['maintenance']['enabled'] ) ? 1 : 0,
		'blocking' => ! empty( $in['maintenance']['blocking'] ) ? 1 : 0,
		'message'  => sanitize_text_field( $in['maintenance']['message'] ?? '' ),
	);

	$out['announcements'] = array();
	for ( $i = 0; $i < 3; $i++ ) {
		$row = $in['announcements'][ $i ] ?? array();
		$out['announcements'][ $i ] = array(
			'title'   => sanitize_text_field( $row['title'] ?? '' ),
			'message' => sanitize_text_field( $row['message'] ?? '' ),
			'url'     => saralbook_app_allowed_url( $row['url'] ?? '' ),
		);
	}

	$out['services'] = array();
	foreach ( array_keys( saralbook_app_services() ) as $id ) {
		$row = $in['services'][ $id ] ?? array();
		$out['services'][ $id ] = array(
			'enabled' => ! empty( $row['enabled'] ) ? 1 : 0,
			'message' => sanitize_text_field( $row['message'] ?? '' ),
		);
	}

	$out['sections'] = array();
	for ( $i = 0; $i < 8; $i++ ) {
		$row  = $in['sections'][ $i ] ?? array();
		$type = in_array( $row['type'] ?? '', array( 'feed', 'platforms', 'recent' ), true ) ? $row['type'] : 'feed';
		$out['sections'][ $i ] = array(
			'type'    => $type,
			'title'   => sanitize_text_field( $row['title'] ?? '' ),
			'titleHi' => sanitize_text_field( $row['titleHi'] ?? '' ),
			'feedUrl' => saralbook_app_allowed_url( $row['feedUrl'] ?? '' ),
			'enabled' => ! empty( $row['enabled'] ) ? 1 : 0,
		);
	}

	$out['version'] = time();
	return $out;
}

function saralbook_app_render_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$o        = get_option( SARALBOOK_APP_OPTION, array() );
	$name     = SARALBOOK_APP_OPTION;
	$m        = $o['maintenance'] ?? array();
	$services = saralbook_app_services();
	?>
	<div class="wrap">
		<h1>SaralBook App</h1>
		<p>Changes appear in the app within a few minutes. Leave "Home sections" completely empty to use the app's built-in Home.</p>
		<form method="post" action="options.php">
			<?php settings_fields( 'saralbook_app' ); ?>

			<h2>Maintenance</h2>
			<p>
				<label><input type="checkbox" name="<?php echo esc_attr( $name ); ?>[maintenance][enabled]" value="1" <?php checked( ! empty( $m['enabled'] ) ); ?>> Show maintenance notice on Home</label><br>
				<label><input type="checkbox" name="<?php echo esc_attr( $name ); ?>[maintenance][blocking]" value="1" <?php checked( ! empty( $m['blocking'] ) ); ?>> Block the whole app with a full-screen message (use only for real emergencies)</label>
			</p>
			<p><input type="text" class="large-text" placeholder="Message (optional)" name="<?php echo esc_attr( $name ); ?>[maintenance][message]" value="<?php echo esc_attr( $m['message'] ?? '' ); ?>"></p>

			<h2>Announcements (max 3)</h2>
			<table class="widefat striped"><thead><tr><th>Title</th><th>Message</th><th>Link (optional, https only, your sites)</th></tr></thead><tbody>
			<?php for ( $i = 0; $i < 3; $i++ ) : $r = $o['announcements'][ $i ] ?? array(); ?>
				<tr>
					<td><input type="text" class="regular-text" name="<?php echo esc_attr( $name ); ?>[announcements][<?php echo (int) $i; ?>][title]" value="<?php echo esc_attr( $r['title'] ?? '' ); ?>"></td>
					<td><input type="text" class="large-text" name="<?php echo esc_attr( $name ); ?>[announcements][<?php echo (int) $i; ?>][message]" value="<?php echo esc_attr( $r['message'] ?? '' ); ?>"></td>
					<td><input type="url" class="regular-text" name="<?php echo esc_attr( $name ); ?>[announcements][<?php echo (int) $i; ?>][url]" value="<?php echo esc_attr( $r['url'] ?? '' ); ?>"></td>
				</tr>
			<?php endfor; ?>
			</tbody></table>

			<h2>Websites (turn one off if it is down)</h2>
			<table class="widefat striped"><thead><tr><th>Website</th><th>Available</th><th>Message when unavailable (optional)</th></tr></thead><tbody>
			<?php foreach ( $services as $id => $label ) :
				$r       = $o['services'][ $id ] ?? array();
				$enabled = isset( $r['enabled'] ) ? ! empty( $r['enabled'] ) : true; ?>
				<tr>
					<td><?php echo esc_html( $label ); ?></td>
					<td><input type="checkbox" name="<?php echo esc_attr( $name ); ?>[services][<?php echo esc_attr( $id ); ?>][enabled]" value="1" <?php checked( $enabled ); ?>></td>
					<td><input type="text" class="large-text" name="<?php echo esc_attr( $name ); ?>[services][<?php echo esc_attr( $id ); ?>][message]" value="<?php echo esc_attr( $r['message'] ?? '' ); ?>"></td>
				</tr>
			<?php endforeach; ?>
			</tbody></table>

			<h2>Home sections (top to bottom, max 8)</h2>
			<p><strong>Type "Latest posts"</strong> needs a Feed URL, for example<br>
			<code>https://examjobalert.com/wp-json/wp/v2/posts?categories=12&amp;per_page=6</code><br>
			To find a category number open <code>https://examjobalert.com/wp-json/wp/v2/categories?search=admit</code> in your browser and look for <code>"id"</code>.</p>
			<table class="widefat striped"><thead><tr><th>On</th><th>Type</th><th>Title (English)</th><th>Title (Hindi)</th><th>Feed URL</th></tr></thead><tbody>
			<?php for ( $i = 0; $i < 8; $i++ ) :
				$r    = $o['sections'][ $i ] ?? array();
				$type = $r['type'] ?? 'feed';
				$on   = ! empty( $r['enabled'] );
				$base = esc_attr( $name ) . '[sections][' . (int) $i . ']'; ?>
				<tr>
					<td><input type="checkbox" name="<?php echo $base; // phpcs:ignore WordPress.Security.EscapeOutput ?>[enabled]" value="1" <?php checked( $on ); ?>></td>
					<td>
						<select name="<?php echo $base; // phpcs:ignore WordPress.Security.EscapeOutput ?>[type]">
							<option value="feed" <?php selected( $type, 'feed' ); ?>>Latest posts</option>
							<option value="platforms" <?php selected( $type, 'platforms' ); ?>>Our platforms</option>
							<option value="recent" <?php selected( $type, 'recent' ); ?>>Recently viewed</option>
						</select>
					</td>
					<td><input type="text" name="<?php echo $base; // phpcs:ignore WordPress.Security.EscapeOutput ?>[title]" value="<?php echo esc_attr( $r['title'] ?? '' ); ?>"></td>
					<td><input type="text" name="<?php echo $base; // phpcs:ignore WordPress.Security.EscapeOutput ?>[titleHi]" value="<?php echo esc_attr( $r['titleHi'] ?? '' ); ?>"></td>
					<td><input type="url" class="large-text" name="<?php echo $base; // phpcs:ignore WordPress.Security.EscapeOutput ?>[feedUrl]" value="<?php echo esc_attr( $r['feedUrl'] ?? '' ); ?>"></td>
				</tr>
			<?php endfor; ?>
			</tbody></table>

			<?php submit_button(); ?>
		</form>
		<p>App reads: <a href="<?php echo esc_url( rest_url( 'saralbook/v1/config' ) ); ?>" target="_blank"><?php echo esc_html( rest_url( 'saralbook/v1/config' ) ); ?></a></p>
	</div>
	<?php
}

/* ---------- Public JSON used by the app ---------- */

add_action( 'rest_api_init', function () {
	register_rest_route( 'saralbook/v1', '/config', array(
		'methods'             => 'GET',
		'callback'            => 'saralbook_app_rest_config',
		'permission_callback' => '__return_true',
	) );
} );

function saralbook_app_rest_config() {
	$o = get_option( SARALBOOK_APP_OPTION, array() );
	$m = $o['maintenance'] ?? array();

	$out = array(
		'version'       => (int) ( $o['version'] ?? 1 ),
		'maintenance'   => array(
			'enabled'  => ! empty( $m['enabled'] ),
			'blocking' => ! empty( $m['blocking'] ),
			'message'  => (string) ( $m['message'] ?? '' ),
		),
		'announcements' => array(),
		'services'      => array(),
	);

	foreach ( $o['announcements'] ?? array() as $i => $a ) {
		if ( '' === ( $a['title'] ?? '' ) && '' === ( $a['message'] ?? '' ) ) {
			continue;
		}
		$out['announcements'][] = array(
			'id'      => 'a' . $i,
			'title'   => (string) $a['title'],
			'message' => (string) $a['message'],
			'url'     => (string) ( $a['url'] ?? '' ),
		);
	}

	foreach ( array_keys( saralbook_app_services() ) as $id ) {
		$r                     = $o['services'][ $id ] ?? array();
		$out['services'][ $id ] = array(
			'enabled' => isset( $r['enabled'] ) ? ! empty( $r['enabled'] ) : true,
			'message' => (string) ( $r['message'] ?? '' ),
		);
	}

	// Sections are only sent when you filled some in; otherwise the app uses its built-in Home.
	$sections = array();
	$used     = array();
	foreach ( $o['sections'] ?? array() as $i => $s ) {
		if ( empty( $s['enabled'] ) ) {
			continue;
		}
		if ( 'feed' === $s['type'] && '' === $s['feedUrl'] ) {
			continue;
		}
		$id = preg_replace( '/[^a-z0-9_-]/', '', strtolower( str_replace( ' ', '-', (string) $s['title'] ) ) );
		$id = substr( (string) $id, 0, 30 );
		if ( '' === $id || isset( $used[ $id ] ) ) {
			$id = 'section-' . ( (int) $i + 1 );
		}
		$used[ $id ] = true;
		$sections[]  = array(
			'id'      => $id,
			'type'    => $s['type'],
			'title'   => (string) $s['title'],
			'titleHi' => (string) $s['titleHi'],
			'feedUrl' => (string) $s['feedUrl'],
		);
	}
	if ( ! empty( $sections ) ) {
		$out['sections'] = $sections;
	}

	$response = new WP_REST_Response( $out );
	$response->header( 'Cache-Control', 'public, max-age=60' );
	return $response;
}
