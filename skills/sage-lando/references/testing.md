Deep reference for testing Sage/Acorn projects. Loaded on demand from `skills/sage-lando/SKILL.md`.

# Testing

Setting up Pest in the Sage/Acorn theme — installing dependencies, writing unit and feature tests, and mocking WordPress functions with Brain Monkey.

## Setup Pest

Install Pest in the theme:
```bash
lando theme-composer require --dev pestphp/pest
lando theme-composer require --dev mockery/mockery
lando theme-composer require --dev brain/monkey
```

### `phpunit.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
    bootstrap="vendor/autoload.php"
    colors="true"
>
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>app</directory>
        </include>
    </source>
</phpunit>
```

### `tests/Pest.php`

```php
<?php

uses()->beforeEach(function () {
    \Brain\Monkey\setUp();
})->afterEach(function () {
    \Brain\Monkey\tearDown();
})->in('Unit');
```

### Directory structure

```
tests/
├── Pest.php
└── Unit/
    └── Services/
        └── FeaturedContentServiceTest.php
```

## Writing Tests

### Testing a Service class

```php
// tests/Unit/Services/FeaturedContentServiceTest.php
use App\Services\FeaturedContentService;
use Brain\Monkey\Functions;

it('returns featured posts', function () {
    $fakePosts = [
        (object) ['ID' => 1, 'post_title' => 'Post 1'],
        (object) ['ID' => 2, 'post_title' => 'Post 2'],
    ];

    Functions\expect('get_posts')
        ->once()
        ->with(\Mockery::type('array'))
        ->andReturn($fakePosts);

    $service = new FeaturedContentService(limit: 3);
    $result = $service->getFeatured();

    expect($result)->toHaveCount(2);
    expect($result[0]->post_title)->toBe('Post 1');
});

it('respects the configured limit', function () {
    Functions\expect('get_posts')
        ->once()
        ->with(\Mockery::on(function ($args) {
            return $args['posts_per_page'] === 5;
        }))
        ->andReturn([]);

    $service = new FeaturedContentService(limit: 5);
    $service->getFeatured();
});
```

### Mocking WordPress functions with Brain\Monkey

```php
use Brain\Monkey\Functions;

// Expect a function to be called and return a value
Functions\expect('get_field')
    ->with('subtitle', 42)
    ->andReturn('My Subtitle');

// Stub a function (don't care how many times it's called)
Functions\stubs([
    'get_permalink' => 'https://example.com/post',
    'esc_html' => function ($text) { return $text; },
    '__' => function ($text) { return $text; },
]);
```

Brain\Monkey lets you test PHP classes that call WordPress functions without loading WordPress. It mocks the functions at the PHP level.

**What to test:** Focus on `Services/` classes — they contain business logic and are designed to be testable. Avoid testing Composers and Components directly (they depend on the full Acorn container).

## Running Tests

```bash
# Add tooling to .lando.yml
# tooling:
#   test:
#     service: appserver
#     cmd: ./content/themes/{theme}/vendor/bin/pest --configuration=content/themes/{theme}/phpunit.xml

lando test
```

Or run directly:
```bash
lando ssh -c "cd /app/content/themes/{theme} && vendor/bin/pest"
```
