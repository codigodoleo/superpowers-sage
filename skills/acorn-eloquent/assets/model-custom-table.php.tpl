<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class {{CLASS_NAME}} extends Model
{
    use HasFactory;

    /** WordPress-prefixed table name — always declare explicitly. */
    protected $table = '{{TABLE_NAME}}';

    /** Custom primary key — change if the column is not 'id'. */
    protected $primaryKey = 'id';

    /** Whether the primary key is auto-incrementing. */
    public $incrementing = true;

    /** Primary key type — 'int' or 'string'. */
    protected $keyType = 'int';

    /**
     * Whether the table has created_at / updated_at columns.
     * Set to false for tables without timestamp columns.
     */
    public $timestamps = true;

    protected $fillable = [
        // 'column_one',
        // 'column_two',
    ];

    protected $casts = [
        // 'is_active'   => 'boolean',
        // 'metadata'    => 'array',
        // 'published_at' => 'datetime',
    ];
}
