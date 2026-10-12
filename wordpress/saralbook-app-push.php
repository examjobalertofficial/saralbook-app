<?php
/**
 * Plugin Name: SaralBook App Push
 * Description: Sends a push notification to the SaralBook app (through OneSignal) when a post is published, and when an existing post is moved into categories you choose (for example Admit Card, Result). No coding needed.
 * Version: 1.0.0
 * Author: SaralBook
 * License: GPLv2 or later
 *
 * Setup: see docs/NOTIFICATIONS.md in the app project. Short version:
 *  1. Settings > SaralBook App Push: paste your OneSignal App ID and REST API Key.
 *  2. Turn OFF automatic sending in the other "OneSignal Push Notifications" plugin
 *     (otherwise people get two notifications). Keep that plugin for the website visitors' subscriptions.
 *  3. Press "Send test notification".
 * To keep one post silent, give it the tag  no-push.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

const SARALBOOK_PUSH_OPTION = 'saralbook_push';
const SARALBOOK_PUSH_RESULT = 'saralbook_push_last_result';

function saralbook_push_options() {
	$o = get_option( SARALBOOK_PUSH_OPTION, array() );
	$o = is_array( $o ) ? $o : array();
	return array_merge(
		array(
			'app_id'          => '',
			'rest_key'        => '',
			'segment'         => 'Total Subscriptions',
			'notify_new'      => 1,
			'update_cats'     => 'admit-card, result, answer-key',
			'notify_any_edit' => 0,
			'cooldown_hours'  => 6,
		),
		$o
	);
}

/** What happened during this request; sent once, at the very end. */
$GLOBALS['saralbook_push_events'] = array();

function saralbook_push_record( $post_id, $kind ) {
	$post = get_post( $post_id );
	if ( ! $post || 'post' !== $post->post_type || wp_is_post_revision( $post_id ) || ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) ) {
		return;
	}
	if ( 'publish' !== $post->post_status ) {
		return;
	}
	$events = &$GLOBALS['saralbook_push_events'];
	// "new" beats "category" beats "edit": one notification per post per request.
	$rank = array( 'edit' => 1, 'category' => 2, 'new' => 3 );
	$old  = $events[ $post_id ] ?? '';
	if ( '' === $old || $rank[ $kind ] > $rank[ $old ] ) {
		$events[ $post_id ] = $kind;
	}
}

// A post goes live (draft/pending/scheduled -> published).
add_action(
	'transition_post_status',
	function ( $new, $old, $post ) {
		if ( 'publish' === $new && 'publish' !== $old && $post instanceof WP_Post ) {
			$o = saralbook_push_options();
			if ( ! empty( $o['notify_new'] ) ) {
				saralbook_push_record( $post->ID, 'new' );
			}
		}
	},
	10,
	3
);

// An already published post is moved into a category you listed.
add_action(
	'set_object_terms',
	function ( $object_id, $terms, $tt_ids, $taxonomy, $append, $old_tt_ids ) {
		if ( 'category' !== $taxonomy ) {
			return;
		}
		$o       = saralbook_push_options();
		$wanted  = array_filter( array_map( 'trim', explode( ',', strtolower( (string) $o['update_cats'] ) ) ) );
		if ( empty( $wanted ) ) {
			return;
		}
		$added = array_diff( array_map( 'intval', (array) $tt_ids ), array_map( 'intval', (array) $old_tt_ids ) );
		foreach ( $added as $tt_id ) {
			$term = get_term_by( 'term_taxonomy_id', $tt_id, 'category' );
			if ( $term && ( in_array( strtolower( $term->slug ), $wanted, true ) || in_array( (string) $term->term_id, $wanted, true ) ) ) {
				saralbook_push_record( $object_id, 'category' );
				return;
			}
		}
	},
	10,
	6
);

// Optional: any edit of a published post (off by default, it can be noisy).
add_action(
	'post_updated',
	function ( $post_id, $after, $before ) {
		$o = saralbook_push_options();
		if ( empty( $o['notify_any_edit'] ) || 'publish' !== $after->post_status || 'publish' !== $before->post_status ) {
			return;
		}
		if ( $after->post_title !== $before->post_title || $after->post_content !== $before->post_content ) {
			saralbook_push_record( $post_id, 'edit' );
		}
	},
	10,
	3
);

add_action(
	'shutdown',
	function () {
		foreach ( $GLOBALS['saralbook_push_events'] as $post_id => $kind ) {
			saralbook_push_send_for_post( (int) $post_id, $kind );
		}
		$GLOBALS['saralbook_push_events'] = array();
	}
);

function saralbook_push_send_for_post( $post_id, $kind ) {
	$o    = saralbook_push_options();
	$post = get_post( $post_id );
	if ( ! $post || has_tag( 'no-push', $post ) ) {
		return;
	}
	if ( 'new' !== $kind ) {
		$last = (int) get_post_meta( $post_id, '_saralbook_push_last', true );
		if ( $last && ( time() - $last ) < max( 1, (int) $o['cooldown_hours'] ) * HOUR_IN_SECONDS ) {
			return; // told people about this post recently
		}
	}
	$title   = wp_strip_all_tags( html_entity_decode( get_the_title( $post ), ENT_QUOTES, 'UTF-8' ) );
	$prefix  = 'new' === $kind ? 'New: ' : 'Updated: ';
	$sent    = saralbook_push_send( $prefix . $title, get_permalink( $post ), $post_id );
	if ( $sent ) {
		update_post_meta( $post_id, '_saralbook_push_last', time() );
	}
}

/** Sends one notification to everyone subscribed (app and website). Returns true on success. */
function saralbook_push_send( $message, $url, $post_id = 0 ) {
	$o = saralbook_push_options();
	if ( '' === $o['app_id'] || '' === $o['rest_key'] ) {
		update_option( SARALBOOK_PUSH_RESULT, 'Not sent: App ID or REST API Key is missing.', false );
		return false;
	}
	$body = array(
		'app_id'            => $o['app_id'],
		'target_channel'    => 'push',
		'included_segments' => array( $o['segment'] ),
		'headings'          => array( 'en' => wp_specialchars_decode( get_bloginfo( 'name' ), ENT_QUOTES ) ),
		'contents'          => array( 'en' => $message ),
		'url'               => esc_url_raw( $url ),
		'data'              => array( 'post_id' => (int) $post_id ),
	);
	$res = wp_remote_post(
		'https://api.onesignal.com/notifications?c=push',
		array(
			'timeout' => 10,
			'headers' => array(
				'Content-Type'  => 'application/json; charset=utf-8',
				'Authorization' => 'Key ' . $o['rest_key'],
			),
			'body'    => wp_json_encode( $body ),
		)
	);
	if ( is_wp_error( $res ) ) {
		update_option( SARALBOOK_PUSH_RESULT, gmdate( 'Y-m-d H:i' ) . ' UTC - failed: ' . $res->get_error_message(), false );
		return false;
	}
	$code = (int) wp_remote_retrieve_response_code( $res );
	$ok   = $code >= 200 && $code < 300;
	$text = wp_remote_retrieve_body( $res );
	update_option(
		SARALBOOK_PUSH_RESULT,
		gmdate( 'Y-m-d H:i' ) . ' UTC - ' . ( $ok ? 'sent' : 'FAILED' ) . ' (HTTP ' . $code . ') ' . substr( wp_strip_all_tags( $text ), 0, 300 ),
		false
	);
	return $ok;
}

add_action(
	'admin_menu',
	function () {
		add_options_page( 'SaralBook App Push', 'SaralBook App Push', 'manage_options', 'saralbook-app-push', 'saralbook_push_page' );
	}
);

function saralbook_push_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$o = saralbook_push_options();
	if ( isset( $_POST['saralbook_push_nonce'] ) && wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['saralbook_push_nonce'] ) ), 'saralbook_push' ) ) {
		if ( isset( $_POST['test'] ) ) {
			$ok = saralbook_push_send( 'Test notification from SaralBook', home_url( '/' ) );
			echo $ok ? '<div class="updated"><p>Test sent. Check your phone.</p></div>' : '<div class="error"><p>Test failed - see the result below.</p></div>';
		} else {
			$in  = isset( $_POST['sb'] ) && is_array( $_POST['sb'] ) ? wp_unslash( $_POST['sb'] ) : array(); // phpcs:ignore WordPress.Security.ValidatedSanitizedInput
			$key = trim( sanitize_text_field( $in['rest_key'] ?? '' ) );
			$new = array(
				'app_id'          => preg_match( '/^[0-9a-fA-F-]{36}$/', trim( (string) ( $in['app_id'] ?? '' ) ) ) ? strtolower( trim( $in['app_id'] ) ) : '',
				'rest_key'        => '' !== $key ? $key : $o['rest_key'], // blank = keep the saved key
				'segment'         => sanitize_text_field( $in['segment'] ?? 'Total Subscriptions' ) ?: 'Total Subscriptions',
				'notify_new'      => ! empty( $in['notify_new'] ) ? 1 : 0,
				'update_cats'     => sanitize_text_field( $in['update_cats'] ?? '' ),
				'notify_any_edit' => ! empty( $in['notify_any_edit'] ) ? 1 : 0,
				'cooldown_hours'  => max( 1, min( 168, (int) ( $in['cooldown_hours'] ?? 6 ) ) ),
			);
			update_option( SARALBOOK_PUSH_OPTION, $new, false );
			$o = saralbook_push_options();
			echo '<div class="updated"><p>Saved.</p></div>';
		}
	}
	?>
	<div class="wrap"><h1>SaralBook App Push</h1>
	<form method="post">
		<?php wp_nonce_field( 'saralbook_push', 'saralbook_push_nonce' ); ?>
		<table class="form-table"><tbody>
			<tr><th>OneSignal App ID</th><td><input type="text" class="regular-text" name="sb[app_id]" value="<?php echo esc_attr( $o['app_id'] ); ?>" placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"></td></tr>
			<tr><th>REST API Key</th><td><input type="password" class="regular-text" name="sb[rest_key]" value="" autocomplete="off" placeholder="<?php echo '' === $o['rest_key'] ? 'paste the key' : 'saved (leave empty to keep it)'; ?>"><p class="description">Secret. Stays on this website, never inside the app.</p></td></tr>
			<tr><th>Who gets it</th><td><input type="text" class="regular-text" name="sb[segment]" value="<?php echo esc_attr( $o['segment'] ); ?>"><p class="description">OneSignal segment name. Normally "Total Subscriptions" (app and website visitors).</p></td></tr>
			<tr><th>New posts</th><td><label><input type="checkbox" name="sb[notify_new]" value="1" <?php checked( ! empty( $o['notify_new'] ) ); ?>> Notify when a post is published</label></td></tr>
			<tr><th>Moved into categories</th><td><input type="text" class="large-text" name="sb[update_cats]" value="<?php echo esc_attr( $o['update_cats'] ); ?>"><p class="description">Category slugs or IDs, separated by commas. When an already published post is added to one of these (for example it becomes an Admit Card), people get "Updated: title". Leave empty to turn off.</p></td></tr>
			<tr><th>Any edit</th><td><label><input type="checkbox" name="sb[notify_any_edit]" value="1" <?php checked( ! empty( $o['notify_any_edit'] ) ); ?>> Also notify when the title or text of a published post changes (can be noisy)</label></td></tr>
			<tr><th>Quiet period (hours)</th><td><input type="number" min="1" max="168" name="sb[cooldown_hours]" value="<?php echo (int) $o['cooldown_hours']; ?>"><p class="description">The same post will not trigger an "Updated" notification more than once in this time. A brand-new post always notifies.</p></td></tr>
		</tbody></table>
		<?php submit_button( 'Save' ); ?>
		<p>To keep one post silent, give it the tag <code>no-push</code>.</p>
		<p><button class="button" name="test" value="1">Send test notification</button></p>
	</form>
	<p><strong>Last result:</strong> <?php echo esc_html( (string) get_option( SARALBOOK_PUSH_RESULT, 'nothing sent yet' ) ); ?></p>
	</div>
	<?php
}
