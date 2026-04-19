<?php

namespace App\Abilities;

use Roots\AcornAi\Abilities\Ability;

class {{ABILITY_NAME}}Ability extends Ability
{
    public string $name = '{{snake_name}}';
    public string $description = 'Full-text search across {{post_type}} posts.';

    public array $schema = [
        'type' => 'object',
        'required' => ['query'],
        'properties' => [
            'query' => ['type' => 'string', 'description' => 'Search term.'],
            'limit' => ['type' => 'integer', 'minimum' => 1, 'maximum' => 50],
        ],
    ];

    public function execute(array $args): array
    {
        $query = new \WP_Query([
            'post_type'      => '{{post_type}}',
            's'              => $args['query'],
            'posts_per_page' => $args['limit'] ?? 10,
        ]);

        return array_map(fn ($post) => [
            'id'      => $post->ID,
            'title'   => $post->post_title,
            'excerpt' => wp_trim_words($post->post_content, 20),
        ], $query->posts);
    }
}
