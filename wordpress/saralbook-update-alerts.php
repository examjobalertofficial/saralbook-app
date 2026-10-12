<?php
/**
 * Plugin Name: SaralBook Update Alerts
 * Description: Sends a push alert to the SaralBook app (through OneSignal) when a post that is ALREADY published is updated - for example moved into "Admit Card" or "Result", or its title is changed. New posts are left to the OneSignal plugin, so nobody gets two alerts.
 * Version: 1.0.0
 * Author: SaralBook
 * License: GPLv2 or later
 *
 * Setup: Settings > SaralBook Update Alerts. Paste your OneSignal App ID and REST API Key
 * (OneSignal dashboard > Settings > Keys & IDs). The key stays on this website only; it is never put in the app.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

const SARALBOOK_ALERTS_OPTION = 'saralbook_update_alerts';
const SARALBOOK_ALERTS_META   = '_saralbook_alert_last';

function saralbook_alerts_settings() {
	$d = array(
		'app_id'      => '',
		'api_key'     => '',
		'segment'     => 'Total Subscriptions',
		'on_category' => 1,
		'on_title'    => 1,
		'throttle'    => 3,
	);
	$o = get_option( SARALBOOK_ALERTS_OPTION, array() );
	return is_array( $o ) ? array_merge( $d, $o ) : $d;
}

/** What happened to posts during this request: filled by the hooks, sent at shutdown. */
function saralbook_alerts_state( $key = null, $value = null ) {
	static $state = array(
		'queue' => array(),
		'fresh' => array(),
	);
	if ( null === $key ) {
		return $state;
	}
	$state[ $key ] = $value;
	return $state;
}

function saralbook_alerts_queue_add( $post_id, $what, $detail = '' ) {
	$s = saralbook_alerts_state();
	$q = $s['queue'];
	if ( ! isset( $q[ $post_id ] ) ) {
		$q[ $post_id ] = array( 'cats' => array(), 'title' => false );
	}
	if ( 'cat' === $what && '' !== $detail ) {
		$q[ $post_id ]['cats'][] = $detail;
	}
	if ( 'title' === $what ) {
		$q[ $post_id ]['title'] = true;
	}
	saralbook_alerts_state( 'queue', $q );
}

/** A category was added to a post. */
add_action(
	'set_object_terms',
	function ( $object_id, $terms, $tt_ids, $taxonomy, $append, $old_tt_ids ) {
		if ( 'category' !== $taxonomy || wp_is_post_revision( $object_id ) ) {
			return;
		}
		$o = saralbook_alerts_settings();
		if ( empty( $o['on_category'] ) ) {
			return;
		}
		foreach ( array_diff( (array) $tt_ids, (array) $old_tt_ids ) as $tt_id ) {
			$term = get_term_by( 'term_taxonomy_id', (int) $tt_id, 'category' );
			if ( $term && ! is_wp_error( $term ) ) {
				saralbook_alerts_queue_add( (int) $object_id, 'cat', $term->name );
			}
		}
	},
	10,
	6
);

/** The title of a published post was changed. */
add_action(
	'post_updated',
	function ( $post_id, $after, $before ) {
		$o = saralbook_alerts_settings();
		if ( empty( $o['on_title'] ) || wp_is_post_revision( $post_id ) ) {
			return;
		}
		if ( 'publish' === $before->post_status && 'publish' === $after->post_status && $before->post_title !== $after->post_title ) {
			saralbook_alerts_queue_add( (int) $post_id, 'title' );
		}
	},
	10,
	3
);

/** A post that goes live right now is "new": the OneSignal plugin announces it, we stay quiet. */
add_action(
	'transition_post_status',
	function ( $new, $old, $post ) {
		if ( 'publish' === $new && 'publish' !== $old ) {
			$s            = saralbook_alerts_state();
			$f            = $s['fresh'];
			$f[ $post->ID ] = true;
			saralbook_alerts_state( 'fresh', $f );
		}
	},
	10,
	3
);

/** Sends the alerts once the page has been saved. */
add_action(
	'shutdown',
	function () {
		$s = saralbook_alerts_state();
		if ( empty( $s['queue'] ) ) {
			return;
		}
		$o = saralbook_alerts_settings();
		if ( '' === $o['app_id'] || '' === $o['api_key'] ) {
			return;
		}
		foreach ( $s['queue'] as $post_id => $info ) {
			if ( ! empty( $s['fresh'][ $post_id ] ) ) {
				continue; // brand-new post
			}
			$post = get_post( $post_id );
			if ( ! $post || 'publish' !== $post->post_status || 'post' !== $post->post_type ) {
				continue;
			}
			// Published only a few minutes ago: still "new", the other plugin covers it.
			if ( time() - strtotime( $post->post_date_gmt . ' UTC' ) < 600 ) {
				continue;
			}
			$last = (int) get_post_meta( $post_id, SARALBOOK_ALERTS_META, true );
			if ( $last && ( time() - $last ) < max( 1, (int) $o['throttle'] ) * HOUR_IN_SECONDS ) {
				continue; // at most one alert per post every few hours
			}
			$cats = array_values( array_unique( $info['cats'] ) );
			$text = $cats ? 'Updated - now in: ' . implode( ', ', $cats ) : 'Updated';
			$res  = saralbook_alerts_send(
				html_entity_decode( get_the_title( $post ), ENT_QUOTES, 'UTF-8' ),
				$text,
				get_permalink( $post )
			);
			if ( $res['ok'] ) {
				update_post_meta( $post_id, SARALBOOK_ALERTS_META, time() );
			}
		}
	}
);

/** Calls OneSignal. Returns array( ok => bool, message => string ). */
function saralbook_alerts_send( $heading, $text, $url ) {
	$o = saralbook_alerts_settings();
	if ( '' === $o['app_id'] || '' === $o['api_key'] ) {
		return array( 'ok' => false, 'message' => 'App ID or REST API key is missing.' );
	}
	$body = array(
		'app_id'            => $o['app_id'],
		'target_channel'    => 'push',
		'included_segments' => array( $o['segment'] ),
		'headings'          => array( 'en' => $heading ),
		'contents'          => array( 'en' => $text ),
	);
	if ( $url ) {
		$body['url'] = esc_url_raw( $url );
	}
	$r = wp_remote_post(
		'https://api.onesignal.com/notifications?c=push',
		array(
			'timeout' => 10,
			'headers' => array(
				'Authorization' => 'Key ' . $o['api_key'],
				'Content-Type'  => 'application/json; charset=utf-8',
				'Accept'        => 'application/json',
			),
			'body'    => wp_json_encode( $body ),
		)
	);
	if ( is_wp_error( $r ) ) {
		return array( 'ok' => false, 'message' => $r->get_error_message() );
	}
	$code = (int) wp_remote_retrieve_response_code( $r );
	$resp = (string) wp_remote_retrieve_body( $r );
	$ok   = ( $code >= 200 && $code < 300 && false === strpos( $resp, '"errors"' ) );
	return array(
		'ok'      => $ok,
		'message' => 'HTTP ' . $code . ' ' . substr( $resp, 0, 300 ),
	);
}

/* ---------------------------- Settings page ---------------------------- */

add_action(
	'admin_menu',
	function () {
		add_options_page( 'SaralBook Update Alerts', 'SaralBook Update Alerts', 'manage_options', 'saralbook-update-alerts', 'saralbook_alerts_page' );
	}
);

function saralbook_alerts_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$notice = '';
	if ( isset( $_POST['saralbook_alerts_nonce'] ) && wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['saralbook_alerts_nonce'] ) ), 'saralbook_alerts' ) ) {
		$old = saralbook_alerts_settings();
		$in  = isset( $_POST['sa'] ) && is_array( $_POST['sa'] ) ? wp_unslash( $_POST['sa'] ) : array(); // phpcs:ignore WordPress.Security.ValidatedSanitizedInput
		$key = isset( $in['api_key'] ) ? trim( sanitize_text_field( $in['api_key'] ) ) : '';
		$new = array(
			'app_id'      => isset( $in['app_id'] ) ? preg_replace( '/[^0-9a-fA-F-]/', '', (string) $in['app_id'] ) : '',
			'api_key'     => '' !== $key ? $key : $old['api_key'], // empty = keep the saved key
			'segment'     => isset( $in['segment'] ) && '' !== trim( $in['segment'] ) ? sanitize_text_field( $in['segment'] ) : 'Total Subscriptions',
			'on_category' => empty( $in['on_category'] ) ? 0 : 1,
			'on_title'    => empty( $in['on_title'] ) ? 0 : 1,
			'throttle'    => isset( $in['throttle'] ) ? max( 1, min( 72, (int) $in['throttle'] ) ) : 3,
		);
		update_option( SARALBOOK_ALERTS_OPTION, $new );
		$notice = '<div class="updated"><p>Saved.</p></div>';
		if ( isset( $_POST['send_test'] ) ) {
			$res    = saralbook_alerts_send( 'SaralBook test', 'This is a test alert from your website.', home_url( '/' ) );
			$notice .= '<div class="' . ( $res['ok'] ? 'updated' : 'error' ) . '"><p><strong>Test ' . ( $res['ok'] ? 'sent' : 'failed' ) . ':</strong> ' . esc_html( $res['message'] ) . '</p></div>';
		}
	}
	$o = saralbook_alerts_settings();
	echo '<div class="wrap"><h1>SaralBook Update Alerts</h1>';
	echo $notice; // phpcs:ignore WordPress.Security.EscapeOutput
	?>
	<p>Sends an alert to the app when a post that is already published is <strong>moved into a new category</strong>
	(for example Admit Card or Result) or its <strong>title changes</strong>. Brand-new posts are announced by the OneSignal plugin.</p>
	<form method="post">
		<?php wp_nonce_field( 'saralbook_alerts', 'saralbook_alerts_nonce' ); ?>
		<table class="form-table"><tbody>
			<tr><th>OneSignal App ID</th><td><input type="text" class="regular-text" name="sa[app_id]" value="<?php echo esc_attr( $o['app_id'] ); ?>"></td></tr>
			<tr><th>REST API Key</th><td><input type="password" class="regular-text" name="sa[api_key]" value="" autocomplete="off" placeholder="<?php echo '' !== $o['api_key'] ? 'saved - leave empty to keep' : 'paste the key'; ?>"></td></tr>
			<tr><th>Send to segment</th><td><input type="text" class="regular-text" name="sa[segment]" value="<?php echo esc_attr( $o['segment'] ); ?>"> <span class="description">Normally "Total Subscriptions".</span></td></tr>
			<tr><th>Alert when</th><td>
				<label><input type="checkbox" name="sa[on_category]" value="1" <?php checked( ! empty( $o['on_category'] ) ); ?>> a post is moved into a category</label><br>
				<label><input type="checkbox" name="sa[on_title]" value="1" <?php checked( ! empty( $o['on_title'] ) ); ?>> the title of a published post changes</label>
			</td></tr>
			<tr><th>At most one alert per post every</th><td><input type="number" min="1" max="72" name="sa[throttle]" value="<?php echo (int) $o['throttle']; ?>"> hours</td></tr>
		</tbody></table>
		<p>
			<?php submit_button( 'Save', 'primary', 'submit', false ); ?>
			<?php submit_button( 'Save and send a test alert', 'secondary', 'send_test', false ); ?>
		</p>
	</form></div>
	<?php
}
