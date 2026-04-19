Deep reference for Acorn routing and custom post types. Loaded on demand from `skills/sage-lando/SKILL.md`.

# Routing & Content Types

Declarative registration of custom post types, taxonomies, and navigation in Sage via Poet (`config/poet.php`) and Navi.

## Poet (`log1x/poet`)

Poet provides declarative registration of custom post types, taxonomies, block categories, and block patterns via `config/poet.php`. No boilerplate `register_post_type()` calls -- just define arrays and Poet handles the rest.

### Custom Post Types

```php
// config/poet.php
return [
    'post' => [
        'project' => [
            'enter_title_here' => 'Enter project title',
            'menu_icon' => 'dashicons-portfolio',
            'supports' => ['title', 'editor', 'thumbnail', 'excerpt', 'revisions'],
            'show_in_rest' => true,
            'has_archive' => true,
            'public' => true,
            'rewrite' => ['slug' => 'projects'],
            'labels' => [
                'name' => __('Projects', '{theme}'),
                'singular_name' => __('Project', '{theme}'),
                'add_new_item' => __('Add New Project', '{theme}'),
                'edit_item' => __('Edit Project', '{theme}'),
                'all_items' => __('All Projects', '{theme}'),
                'view_item' => __('View Project', '{theme}'),
                'search_items' => __('Search Projects', '{theme}'),
                'not_found' => __('No projects found', '{theme}'),
            ],
        ],

        'testimonial' => [
            'menu_icon' => 'dashicons-format-quote',
            'supports' => ['title', 'editor', 'thumbnail'],
            'show_in_rest' => true,
            'has_archive' => false,
            'public' => true,
            'labels' => [
                'name' => __('Testimonials', '{theme}'),
                'singular_name' => __('Testimonial', '{theme}'),
            ],
        ],

        // Private CPT (not visible on frontend, admin-only)
        'subscriber' => [
            'menu_icon' => 'dashicons-email-alt',
            'supports' => ['title'],
            'show_in_rest' => true,
            'has_archive' => false,
            'public' => false,
            'show_ui' => true,
            'labels' => [
                'name' => __('Subscribers', '{theme}'),
                'singular_name' => __('Subscriber', '{theme}'),
            ],
        ],
    ],
];
```

#### Key Options

- **`supports`** -- which editor features to enable. Common values: `title`, `editor`, `thumbnail`, `excerpt`, `revisions`, `page-attributes`, `custom-fields`. Only include what the content type actually needs.
- **`show_in_rest`** -- required for Gutenberg editor support. Always set to `true` unless you have a specific reason not to (e.g., a legacy metabox-only CPT).
- **`has_archive`** -- when `true`, WordPress creates an archive page at the `rewrite.slug` URL (e.g., `/projects/`). Set to `false` for CPTs that don't need listing pages.
- **`public` vs `show_ui`** -- `public: false, show_ui: true` creates an admin-only CPT with no frontend URLs. Use this for data-only types like subscribers, form entries, or internal records.
- **`rewrite`** -- customize the URL slug. The slug should be the plural, hyphenated form (e.g., `'slug' => 'case-studies'`).
- **`menu_icon`** -- a dashicon name for the admin sidebar. See the WordPress dashicons reference for available icons.
- **`labels`** -- always translate with `__()` using your theme text domain. At minimum provide `name` and `singular_name`; the full set improves the admin UX.

### Taxonomies

```php
// config/poet.php (add to same file)
return [
    'post' => [/* ... */],

    'taxonomy' => [
        'project_type' => [
            'objects' => ['project'],  // Which CPTs this taxonomy attaches to
            'hierarchical' => true,    // true = categories, false = tags
            'show_in_rest' => true,
            'rewrite' => ['slug' => 'project-type'],
            'labels' => [
                'name' => __('Project Types', '{theme}'),
                'singular_name' => __('Project Type', '{theme}'),
                'add_new_item' => __('Add New Project Type', '{theme}'),
                'search_items' => __('Search Project Types', '{theme}'),
            ],
        ],

        'skill' => [
            'objects' => ['project', 'post'],  // Shared across CPTs
            'hierarchical' => false,           // Tag-style
            'show_in_rest' => true,
            'labels' => [
                'name' => __('Skills', '{theme}'),
                'singular_name' => __('Skill', '{theme}'),
            ],
        ],
    ],
];
```

#### Key Options

- **`objects`** -- array of post type slugs this taxonomy applies to. List all CPT slugs that should share the taxonomy.
- **`hierarchical`** -- `true` creates a category-like taxonomy with parent/child relationships (shown as checkboxes in the editor). `false` creates a tag-like flat taxonomy (shown as a token input).
- Taxonomies shared across multiple CPTs: list all CPT slugs in the `objects` array. This is the correct way to create cross-cutting classifications.

### Block Categories

```php
return [
    'post' => [/* ... */],
    'taxonomy' => [/* ... */],

    'block_category' => [
        'theme' => [
            'title' => __('Theme Blocks', '{theme}'),
            'icon' => 'star-filled',
        ],
        'sections' => [
            'title' => __('Page Sections', '{theme}'),
            'icon' => 'layout',
        ],
    ],
];
```

These categories appear in the Gutenberg block inserter. Reference them from your ACF blocks via the `$category` property in the block class.

### Block Patterns

```php
return [
    'block_pattern' => [
        'hero-with-cta' => [
            'title' => __('Hero with CTA', '{theme}'),
            'description' => __('Full-width hero section with call to action button', '{theme}'),
            'categories' => ['theme'],
            'content' => '<!-- wp:acf/hero {"name":"acf/hero"} /-->',
        ],
    ],
];
```

Block patterns let editors insert pre-configured block arrangements. The `content` is serialized block markup -- use the block editor's "Copy block" feature to get the correct markup.

### When Poet Isn't Enough

Use a Service Provider when you need:

- `register_meta()` for REST API custom meta fields
- Complex `register_post_type` args computed at runtime
- Custom REST API endpoints for a CPT
- Custom admin columns with sortable queries
- Hooks that modify CPT behavior (like custom permalink structures)

```php
// app/Providers/ThemeServiceProvider.php → boot()
add_action('init', function () {
    register_post_meta('project', 'project_url', [
        'show_in_rest' => true,
        'single' => true,
        'type' => 'string',
    ]);
});
```

Poet handles the common 90% of CPT/taxonomy registration. Reach for Service Providers only when you need programmatic control.

---

## Navi (`log1x/navi`)

Navi replaces the messy `wp_nav_menu()` HTML output with clean, iterable objects you can render in Blade however you want. Full control over markup with zero Walker classes.

### Register Menus

```php
// app/setup.php
register_nav_menus([
    'primary_navigation' => __('Primary Navigation', '{theme}'),
    'footer_navigation' => __('Footer Navigation', '{theme}'),
    'social_navigation' => __('Social Links', '{theme}'),
]);
```

### Basic Usage in Blade

```blade
@if ($navigation = \Log1x\Navi\Facades\Navi::build('primary_navigation'))
  <nav aria-label="Primary">
    <ul class="flex items-center gap-6">
      @foreach ($navigation->toArray() as $item)
        <li @class(['current' => $item->active])>
          <a href="{{ $item->url }}" @if($item->target) target="{{ $item->target }}" @endif>
            {{ $item->label }}
          </a>

          {{-- Dropdown for children --}}
          @if ($item->children)
            <ul class="dropdown">
              @foreach ($item->children as $child)
                <li @class(['current' => $child->active])>
                  <a href="{{ $child->url }}">{{ $child->label }}</a>
                </li>
              @endforeach
            </ul>
          @endif
        </li>
      @endforeach
    </ul>
  </nav>
@endif
```

### Navi Item Properties

| Property | Type | Description |
|---|---|---|
| `$item->label` | string | Menu item display text |
| `$item->url` | string | Full URL |
| `$item->target` | string\|null | Link target (`_blank`, etc.) |
| `$item->active` | bool | `true` if current page or ancestor |
| `$item->children` | array | Submenu items (same structure, recursive) |
| `$item->classes` | array | CSS classes assigned in WP menu admin |
| `$item->id` | int | Menu item ID |
| `$item->parent` | int\|null | Parent menu item ID |

### Navigation as a Blade Component

For reusable navigation across templates, create a dedicated component:

```bash
lando acorn make:component Navigation
```

```php
// app/View/Components/Navigation.php
namespace App\View\Components;

use Illuminate\View\Component;
use Illuminate\Contracts\View\View;
use Log1x\Navi\Facades\Navi;

class Navigation extends Component
{
    public ?object $items;

    public function __construct(
        public string $menu = 'primary_navigation',
    ) {
        $navigation = Navi::build($this->menu);
        $this->items = $navigation ? $navigation->toArray() : null;
    }

    public function render(): View
    {
        return view('components.navigation');
    }
}
```

Usage in any Blade template:

```blade
<x-navigation />
<x-navigation menu="footer_navigation" />
```

### Mobile-Responsive Navigation Pattern

A practical responsive nav using Tailwind CSS and Alpine.js -- the standard Sage frontend stack:

```blade
{{-- resources/views/components/navigation.blade.php --}}
<nav x-data="{ open: false }" class="relative">
  {{-- Mobile toggle --}}
  <button
    @click="open = !open"
    class="lg:hidden p-2"
    aria-label="Toggle menu"
  >
    <svg x-show="!open" class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
    </svg>
    <svg x-show="open" class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
    </svg>
  </button>

  @if ($items)
    <ul
      :class="open ? 'block' : 'hidden'"
      class="lg:flex lg:items-center lg:gap-6"
    >
      @foreach ($items as $item)
        <li @class(['relative group', 'current' => $item->active])>
          <a
            href="{{ $item->url }}"
            class="block py-2 lg:py-0 hover:text-primary"
          >
            {{ $item->label }}
          </a>

          @if ($item->children)
            <ul class="lg:absolute lg:hidden lg:group-hover:block bg-white shadow-lg rounded-lg p-2 min-w-48">
              @foreach ($item->children as $child)
                <li>
                  <a href="{{ $child->url }}" class="block px-4 py-2 hover:bg-gray-50 rounded">
                    {{ $child->label }}
                  </a>
                </li>
              @endforeach
            </ul>
          @endif
        </li>
      @endforeach
    </ul>
  @endif
</nav>
```

This pattern gives you:

- **Desktop** (`lg:` and up): horizontal menu with hover-triggered dropdowns via Tailwind's `group-hover`
- **Mobile** (below `lg:`): hamburger button toggles a vertical menu via Alpine.js `x-data`/`@click`
- **Accessibility**: `aria-label` on the toggle button, semantic `<nav>` element
- **No JavaScript framework dependency**: Alpine.js handles the toggle with minimal overhead
