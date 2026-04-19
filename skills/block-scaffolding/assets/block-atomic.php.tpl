<?php

namespace App\Blocks;

use Log1x\AcfComposer\Block;
use StoutLogic\AcfBuilder\FieldsBuilder;

/**
 * Atomic (leaf) block — no InnerBlocks, renders its own content entirely.
 *
 * Usage: copy this template, rename the class to {{CLASS_NAME}},
 * and replace all {{PLACEHOLDER}} tokens.
 */
class {{CLASS_NAME}} extends Block
{
    public $name = '{{BLOCK_TITLE}}';
    public $description = '{{BLOCK_DESCRIPTION}}';
    public $category = 'theme-blocks';
    public $icon = 'layout';
    public $keywords = [];

    public $spacing = [
        'padding' => null,
        'margin'  => null,
    ];

    public $supports = [
        'align'      => ['wide', 'full'],
        'color'      => ['background' => true, 'text' => true],
        'typography' => ['fontSize' => false],
    ];

    /** Remove $styles entirely for Minimal-mode blocks (single fixed appearance). */
    public $styles = [
        ['label' => 'Light',   'name' => 'light',   'isDefault' => true],
        ['label' => 'Neutral', 'name' => 'neutral'],
        ['label' => 'Dark',    'name' => 'dark'],
    ];

    /**
     * Pass computed data to the Blade view.
     * ACF fields are already available in the view via get_field().
     */
    public function with(): array
    {
        return [
            //
        ];
    }

    /**
     * Declare all ACF fields here — never via the ACF GUI.
     * Field group key is the block slug (kebab-case).
     */
    public function fields(): array
    {
        $fields = new FieldsBuilder('{{BLOCK_SLUG}}');

        $fields
            // ->addText('titulo', ['label' => 'Título'])
            // ->addTextarea('descricao', ['label' => 'Descrição', 'rows' => 3])
            ;

        return $fields->build();
    }

    /**
     * Keep empty. CSS and JS are enqueued by ThemeServiceProvider::boot()
     * via has_block("acf/{{BLOCK_SLUG}}") on wp_enqueue_scripts at priority 20.
     *
     * assets() fires inside render() → after wp_head() → too late for <head>.
     */
    public function assets(array $block): void
    {
        //
    }
}
