Deep reference for Blade templates in Sage. Loaded on demand from `skills/sage-lando/SKILL.md`.

# Blade Templates

Sage uses Laravel Blade as its templating engine — this reference covers view composers, Blade components, template hierarchy, directives, and layout patterns for Acorn-based themes.

## Composers vs Components — Decision Guide

| Criteria | View Composer | Blade Component |
|---|---|---|
| **Purpose** | Inject data into existing WordPress templates | Reusable UI piece with props and slots |
| **Bound to** | Template name(s) in `$views` | A class + view pair, used via `<x-name>` |
| **Created with** | `lando acorn make:composer Name` | `lando acorn make:component Name` |
| **Data flow** | Provides variables to a template automatically | Receives data via props explicitly |
| **Reusable across templates?** | No (tied to specific views) | Yes (use anywhere) |
| **Use when** | A WP template needs backend data | You're building a UI element used in multiple places |

**Rule of thumb:** If you're adding data to `front-page.blade.php`, use a Composer. If you're building a `<x-card>` used across 5 templates, use a Component.

## View Composers

Auto-discovered by Acorn — no registration needed.

### Basic composer

```php
namespace App\View\Composers;

use Roots\Acorn\View\Composer;

class FrontPage extends Composer
{
    protected static $views = ['front-page'];

    public function with(): array
    {
        return [
            'featuredPosts' => $this->getFeaturedPosts(),
            'stats' => $this->getStats(),
        ];
    }

    protected function getFeaturedPosts(): array
    {
        return get_posts([
            'posts_per_page' => 3,
            'meta_key' => 'is_featured',
            'meta_value' => '1',
        ]);
    }

    protected function getStats(): array
    {
        return [
            'projects' => wp_count_posts('project')->publish,
            'clients' => wp_count_posts('client')->publish,
        ];
    }
}
```

### `$views` patterns

```php
// Single template
protected static $views = ['front-page'];

// Multiple templates
protected static $views = ['single-post', 'single-case-study'];

// All templates (global data)
protected static $views = ['*'];

// Partials
protected static $views = ['partials.header', 'partials.footer'];
```

### `with()` vs `override()`

- `with()` — provides variables. If the template already has a variable with the same name, the existing one wins.
- `override()` — same as `with()`, but forces the value even if the variable already exists.

```php
public function with(): array
{
    return ['title' => 'Default Title'];  // Won't overwrite existing $title
}

public function override(): array
{
    return ['title' => 'Forced Title'];  // Always overwrites
}
```

### Dependency injection in composers

```php
use App\Services\FeaturedContentService;

class FrontPage extends Composer
{
    protected static $views = ['front-page'];

    public function __construct(
        protected FeaturedContentService $featured,
    ) {}

    public function with(): array
    {
        return [
            'featuredPosts' => $this->featured->getFeatured(),
        ];
    }
}
```

The container auto-resolves the constructor dependency.

## Blade Components

### Class-based component

Created with `lando acorn make:component Card`:

```php
namespace App\View\Components;

use Illuminate\View\Component;
use Illuminate\Contracts\View\View;

class Card extends Component
{
    public function __construct(
        public string $title,
        public string $description = '',
        public ?string $imageUrl = null,
        public string $variant = 'default',
    ) {}

    public function render(): View
    {
        return view('components.card');
    }
}
```

View (`resources/views/components/card.blade.php`):
```blade
<div {{ $attributes->merge(['class' => "card card--{$variant}"]) }}>
  @if ($imageUrl)
    <img src="{{ $imageUrl }}" alt="{{ $title }}" class="card__image" />
  @endif

  <div class="card__body">
    <h3 class="card__title">{{ $title }}</h3>

    @if ($description)
      <p class="card__description">{{ $description }}</p>
    @endif

    {{ $slot }}
  </div>
</div>
```

Usage:
```blade
<x-card title="Project Alpha" description="A cool project" variant="featured">
  <a href="/projects/alpha">Learn more</a>
</x-card>
```

### Anonymous components (view-only)

Created with `lando acorn make:component Alert --view`. No PHP class — just a Blade file.

```blade
{{-- resources/views/components/alert.blade.php --}}
@props([
    'type' => 'info',
    'dismissible' => false,
])

<div {{ $attributes->merge(['class' => "alert alert--{$type}"]) }} role="alert">
  {{ $slot }}

  @if ($dismissible)
    <button type="button" class="alert__close" aria-label="Close">&times;</button>
  @endif
</div>
```

Usage: `<x-alert type="warning" dismissible>Check your input.</x-alert>`

**When to use anonymous vs class-based:**
- Anonymous: simple UI wrappers, no logic beyond props
- Class-based: needs computed properties, method calls, or injected services

### Props and attributes

```blade
{{-- Declaring props (anonymous components) --}}
@props(['type' => 'button', 'size' => 'md'])

{{-- Props are extracted from attributes automatically --}}
{{-- Everything NOT declared as a prop goes into $attributes --}}

<button
  type="{{ $type }}"
  {{ $attributes->merge(['class' => "btn btn--{$size}"]) }}
>
  {{ $slot }}
</button>
```

Usage: `<x-button type="submit" size="lg" id="save-btn">Save</x-button>`
- `type` and `size` are consumed as props
- `id="save-btn"` passes through to `$attributes`

### Named slots

```blade
{{-- Component view --}}
<article class="article">
  <header>{{ $header }}</header>
  <div class="article__body">{{ $slot }}</div>
  <footer>{{ $footer ?? '' }}</footer>
</article>
```

Usage:
```blade
<x-article>
  <x-slot:header>
    <h2>Article Title</h2>
  </x-slot:header>

  <p>Article body content here...</p>

  <x-slot:footer>
    <span>Published on {{ $date }}</span>
  </x-slot:footer>
</x-article>
```

### Nested components with subdirectories

```bash
lando acorn make:component Cards/ServiceCard
# Creates: app/View/Components/Cards/ServiceCard.php
# Creates: resources/views/components/cards/service-card.blade.php
```

Usage: `<x-cards.service-card title="Web Development" />`

Note the dot notation for subdirectories in Blade.

## Sage Directives (`log1x/sage-directives`)

Common WordPress directives available in Blade:

### Query and loop
```blade
@query(['post_type' => 'project', 'posts_per_page' => 6])
  @posts
    <h2>@title</h2>
    <div>@content</div>
    <a href="@permalink">Read more</a>
  @endposts
@endquery
```

### Conditionals
```blade
@hasfield('subtitle')
  <p class="subtitle">@field('subtitle')</p>
@endfield

@isfront
  {{-- Only on front page --}}
@endisfront

@ispage('about')
  {{-- Only on "about" page --}}
@endispage

@issingle
  {{-- Only on single posts --}}
@endissingle

@isarchive
  {{-- Only on archive pages --}}
@endisarchive
```

### Fields (ACF)
```blade
@field('field_name')           {{-- Echo field value --}}
@hasfield('field_name')        {{-- Check if field has value --}}
@endfield

@fields('repeater_name')
  {{ $item['title'] }}
@endfields

@sub('sub_field_name')         {{-- Inside repeater/group --}}
```

### Assets
```blade
@svg('icon-name')              {{-- Inline SVG from blade-icons --}}
@asset('images/logo.png')      {{-- Theme asset URL --}}
```

### Utility
```blade
@shortcode('[gallery ids="1,2,3"]')
@wpautop($content)
@wpkses($html, 'post')
```

## Template Hierarchy in Sage

Sage maps WordPress's template hierarchy to `resources/views/`:

```
WordPress template       →  Blade view path
─────────────────────────────────────────────
front-page.php           →  resources/views/front-page.blade.php
home.php                 →  resources/views/home.blade.php
single.php               →  resources/views/single.blade.php
single-{post_type}.php   →  resources/views/single-{post_type}.blade.php
page.php                 →  resources/views/page.blade.php
archive.php              →  resources/views/archive.blade.php
archive-{post_type}.php  →  resources/views/archive-{post_type}.blade.php
taxonomy-{taxonomy}.php  →  resources/views/taxonomy-{taxonomy}.blade.php
category.php             →  resources/views/category.blade.php
search.php               →  resources/views/search.blade.php
404.php                  →  resources/views/404.blade.php
index.php                →  resources/views/index.blade.php
```

Page templates use a `Template Name` comment in the Blade file:
```blade
{{--
  Template Name: About Page
--}}

@extends('layouts.app')

@section('content')
  {{-- Template content --}}
@endsection
```

## Layouts and Sections

### The main layout (`resources/views/layouts/app.blade.php`)

```blade
<!doctype html>
<html @php(language_attributes())>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  @php(wp_head())
</head>

<body @php(body_class())>
  @php(wp_body_open())

  @include('partials.header')

  <main class="main">
    @yield('content')
  </main>

  @include('partials.footer')

  @php(wp_footer())
</body>
</html>
```

### Using the layout in templates

```blade
{{-- resources/views/front-page.blade.php --}}
@extends('layouts.app')

@section('content')
  <section class="hero">
    <h1>{{ $title }}</h1>
  </section>

  @include('sections.featured-posts')
@endsection
```

### Multiple layouts

Create additional layouts for different page structures:
- `layouts/app.blade.php` — default (header + content + footer)
- `layouts/landing.blade.php` — no header/footer, full-width
- `layouts/minimal.blade.php` — simplified layout for auth pages

```blade
{{-- In a template --}}
@extends('layouts.landing')
```

### Partials

Shared pieces extracted with `@include`:
```blade
@include('partials.header')
@include('partials.footer')
@include('partials.social-links')

{{-- Pass data to partials --}}
@include('partials.post-card', ['post' => $featuredPost])
```
