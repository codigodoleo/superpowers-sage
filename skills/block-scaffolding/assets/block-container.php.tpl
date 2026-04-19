<?php

namespace App\Blocks;

use Log1x\AcfComposer\Block;
use StoutLogic\AcfBuilder\FieldsBuilder;

/**
 * Container block — renders its own fields plus an InnerBlocks area.
 *
 * The rendered inner block HTML is available in the Blade view as $content.
 * Use {!! $content !!} (unescaped) — never {{ $content }}.
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

    /**
     * Blocks allowed as children. Empty array = all blocks allowed.
     * Restrict to theme blocks for tightly controlled layouts.
     */
    public $allowedBlocks = [
        // 'acf/card-block',
        // 'core/image',
    ];

    /**
     * Default inner block template (pre-populated on first insert).
     * Format: [ 'block-name', attributes, innerBlocks ]
     */
    public $template = [
        // ['acf/card-block', [], []],
    ];

    /**
     * Lock the template structure if needed.
     * 'all' = fully locked; 'insert' = content editable, no add/remove.
     * Remove or set false for a free-form InnerBlocks area.
     */
    // public $templateLock = false;

    /** Remove $styles entirely for Minimal-mode blocks. */
    public $styles = [
        ['label' => 'Light',   'name' => 'light',   'isDefault' => true],
        ['label' => 'Neutral', 'name' => 'neutral'],
        ['label' => 'Dark',    'name' => 'dark'],
    ];

    /**
     * Pass computed data to the Blade view.
     */
    public function with(): array
    {
        return [
            //
        ];
    }

    /**
     * Declare ACF fields for the container block itself (not for inner blocks).
     */
    public function fields(): array
    {
        $fields = new FieldsBuilder('{{BLOCK_SLUG}}');

        $fields
            // ->addText('titulo', ['label' => 'Título'])
            ;

        return $fields->build();
    }

    /**
     * Keep empty. Enqueue via ThemeServiceProvider::boot().
     */
    public function assets(array $block): void
    {
        //
    }
}
