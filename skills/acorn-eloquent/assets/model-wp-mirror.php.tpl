<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Read-only Eloquent mirror of a WordPress core table.
 *
 * IMPORTANT: Never use this model to insert, update, or delete rows.
 * WordPress-managed tables must be written through WP API functions so
 * hooks (save_post, wp_insert_user, cache invalidation) fire correctly.
 *
 * Usage: read-only reads and relationship traversal only.
 */
class {{CLASS_NAME}} extends Model
{
    /** WordPress core table — include the wp_ prefix. */
    protected $table = '{{WP_TABLE}}';

    /**
     * WP core tables use non-standard primary key names.
     * Common values: 'ID' (wp_posts, wp_users), 'term_id' (wp_terms),
     * 'comment_ID' (wp_comments), 'meta_id' (wp_postmeta).
     */
    protected $primaryKey = 'ID';

    public $keyType      = 'int';
    public $incrementing = true;

    /**
     * WordPress core tables have no created_at / updated_at columns.
     * Must be false or Eloquent will error on reads.
     */
    public $timestamps = false;

    /**
     * Guard all columns — WP manages writes, not Eloquent.
     * Do not change to $fillable without fully understanding the implications.
     */
    protected $guarded = ['*'];

    /**
     * Throw on any attempt to write through this model.
     */
    protected static function booted(): void
    {
        static::creating(fn () => throw new \RuntimeException(
            'Use WordPress API functions — writing to {{WP_TABLE}} via Eloquent bypasses hooks.',
        ));

        static::updating(fn () => throw new \RuntimeException(
            'Use WordPress API functions — writing to {{WP_TABLE}} via Eloquent bypasses hooks.',
        ));
    }

    // Add relationship methods below.
    // Example: wp_posts → wp_postmeta
    //
    // public function meta(): \Illuminate\Database\Eloquent\Relations\HasMany
    // {
    //     return $this->hasMany(WpPostMeta::class, 'post_id', 'ID');
    // }
}
