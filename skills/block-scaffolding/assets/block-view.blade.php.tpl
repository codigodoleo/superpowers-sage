@php
    /**
     * $block — ACF block object (provides ->preview, ->style, ->id, etc.)
     * $block_attrs — HTML attribute string from get_block_wrapper_attributes()
     *                carries spacing, alignment, is-style-*, wp-block-acf-* classes.
     *
     * Tailwind v4 note: compose utilities directly (e.g. flex gap-8 px-6 max-w-7xl).
     * Do NOT use @apply in block views. Use @reference "../app.css" in block CSS instead.
     */
    $block_attrs = get_block_wrapper_attributes();
@endphp

{{-- Frontend wrapper — skipped in the Gutenberg editor preview. --}}
{{-- $attributes carries spacing, alignment, is-style-* and block identity classes. --}}
@unless ($block->preview)
  <section {!! $block_attrs !!}>
@endunless

{{-- Custom element root — CSS and JS key off this tag selector. --}}
{{-- Structural utilities (flex, gap, px-*) are appropriate here. --}}
{{-- Colors and typography come from CSS custom properties, not utility classes. --}}
<block-{{BLOCK_SLUG}} class="flex flex-col">

  {{-- ACF fields are available as $field_name variables. --}}
  {{-- Example for atomic block: --}}
  {{-- <x-ui.heading :level="2">{{ $titulo ?? '' }}</x-ui.heading> --}}
  {{-- <p class="mt-4">{{ $descricao ?? '' }}</p> --}}

  {{-- Example for container block — renders inner blocks: --}}
  @isset($content)
    {!! $content !!}
  @else
    {{-- Placeholder shown in the editor when no inner blocks are present. --}}
    {{-- <p class="text-sm opacity-50">Add blocks inside this section.</p> --}}
  @endisset

</block-{{BLOCK_SLUG}}>

@unless ($block->preview)
  </section>
@endunless
