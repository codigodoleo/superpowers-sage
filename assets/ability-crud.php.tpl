<?php

namespace App\Abilities;

use Roots\AcornAi\Abilities\Ability;

class {{ABILITY_NAME}}Ability extends Ability
{
    public string $name = '{{snake_name}}';
    public string $description = 'Create, read, update, or delete a {{post_type}} post.';

    public array $schema = [
        'type' => 'object',
        'required' => ['action'],
        'properties' => [
            'action' => [
                'type' => 'string',
                'enum' => ['create', 'read', 'update', 'delete'],
            ],
            'id'      => ['type' => 'integer'],
            'title'   => ['type' => 'string'],
            'content' => ['type' => 'string'],
            'status'  => ['type' => 'string'],
        ],
    ];

    public function execute(array $args): array
    {
        return match ($args['action']) {
            'create' => $this->createPost($args),
            'read'   => $this->readPost($args['id']),
            'update' => $this->updatePost($args),
            'delete' => $this->deletePost($args['id']),
        };
    }

    private function createPost(array $args): array
    {
        $id = wp_insert_post([
            'post_type'    => '{{post_type}}',
            'post_title'   => $args['title'] ?? '',
            'post_content' => $args['content'] ?? '',
            'post_status'  => $args['status'] ?? 'draft',
        ]);
        return ['id' => $id, 'action' => 'created'];
    }

    private function readPost(int $id): array
    {
        $post = get_post($id);
        if (! $post) return ['error' => 'not found'];
        return ['id' => $post->ID, 'title' => $post->post_title, 'status' => $post->post_status];
    }

    private function updatePost(array $args): array
    {
        wp_update_post(['ID' => $args['id'], 'post_title' => $args['title'] ?? null]);
        return ['id' => $args['id'], 'action' => 'updated'];
    }

    private function deletePost(int $id): array
    {
        wp_delete_post($id, true);
        return ['id' => $id, 'action' => 'deleted'];
    }
}
