<?php

namespace App\Abilities;

use Roots\AcornAi\Abilities\Ability;

class {{ABILITY_NAME}}Ability extends Ability
{
    public string $name = '{{snake_name}}';
    public string $description = 'Query {{post_type}} posts with optional filters.';

    public array $schema = [
        'type' => 'object',
        'properties' => [
            'status' => [
                'type' => 'string',
                'enum' => ['publish', 'draft', 'private'],
                'description' => 'Post status filter.',
            ],
            'limit' => [
                'type' => 'integer',
                'minimum' => 1,
                'maximum' => 100,
                'description' => 'Maximum number of posts to return.',
            ],
        ],
    ];

    public function execute(array $args): array
    {
        $query = new \WP_Query([
            'post_type'      => '{{post_type}}',
            'post_status'    => $args['status'] ?? 'publish',
            'posts_per_page' => $args['limit'] ?? 20,
        ]);

        return array_map(fn ($post) => [
            'id'    => $post->ID,
            'title' => $post->post_title,
            'slug'  => $post->post_name,
            'date'  => $post->post_date,
        ], $query->posts);
    }
}
