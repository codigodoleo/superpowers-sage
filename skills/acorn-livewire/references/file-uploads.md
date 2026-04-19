Deep reference for Livewire file uploads in Sage/Acorn/WordPress with Lando. Loaded on demand from `skills/acorn-livewire/SKILL.md`.

# File Uploads with Livewire

## WithFileUploads Trait

Add `use WithFileUploads` to any component that needs to handle file uploads:

```php
<?php

namespace App\Livewire;

use Livewire\Attributes\Validate;
use Livewire\Component;
use Livewire\WithFileUploads;

class AvatarUpload extends Component
{
    use WithFileUploads;

    #[Validate('image|max:2048')] // 2 MB max
    public $photo;

    public ?string $uploadedUrl = null;

    public function save(): void
    {
        $this->validate();

        // Option A: Store using Laravel filesystem (maps to WordPress uploads)
        $path = $this->photo->store('avatars', 'public');

        // Option B: Sideload into WordPress media library
        $attachmentId = media_handle_sideload([
            'name'     => $this->photo->getClientOriginalName(),
            'tmp_name' => $this->photo->getRealPath(),
        ], 0);

        if (! is_wp_error($attachmentId)) {
            $this->uploadedUrl = wp_get_attachment_url($attachmentId);
            update_user_meta(get_current_user_id(), 'custom_avatar', $attachmentId);
        }

        $this->reset('photo');
    }

    public function render(): \Illuminate\View\View
    {
        return view('livewire.avatar-upload');
    }
}
```

## Blade Upload View

```blade
<div>
    <form wire:submit="save">
        <input type="file" wire:model="photo" />

        @error('photo')
            <p class="text-red-600 text-sm">{{ $message }}</p>
        @enderror

        {{-- Preview before upload --}}
        @if ($photo)
            <img
                src="{{ $photo->temporaryUrl() }}"
                alt="Preview"
                class="mt-2 h-24 w-24 rounded-full object-cover"
            />
        @endif

        <button type="submit" wire:loading.attr="disabled" wire:target="photo">
            Upload
        </button>
    </form>
</div>
```

## Lando Storage Paths

Livewire stores temporary uploads before the component saves them. In Lando, the filesystem driver needs to point to the correct path.

In `.env`:

```env
FILESYSTEM_DISK=public
```

In `config/filesystems.php`:

```php
'disks' => [
    'public' => [
        'driver'     => 'local',
        'root'       => get_template_directory() . '/public/storage',
        'url'        => get_template_directory_uri() . '/public/storage',
        'visibility' => 'public',
    ],
],
```

Create the storage symlink (inside Lando):

```bash
lando acorn storage:link
```

**Temporary file cleanup:** Livewire automatically cleans up temporary files older than 24 hours via a scheduled job. If using the database queue driver, ensure the queue worker is running.

## Multiple File Uploads

```php
use Livewire\Attributes\Validate;

class GalleryUpload extends Component
{
    use WithFileUploads;

    /** @var \Livewire\Features\SupportFileUploads\TemporaryUploadedFile[] */
    #[Validate(['photos.*' => 'image|max:2048'])]
    public array $photos = [];

    public function save(): void
    {
        $this->validate();

        foreach ($this->photos as $photo) {
            media_handle_sideload([
                'name'     => $photo->getClientOriginalName(),
                'tmp_name' => $photo->getRealPath(),
            ], 0);
        }

        $this->reset('photos');
    }
}
```

Blade:

```blade
<input type="file" wire:model="photos" multiple />
```

## S3 Driver

To store uploaded files on S3 instead of the local filesystem:

```env
FILESYSTEM_DISK=s3
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=my-bucket
AWS_URL=https://my-bucket.s3.amazonaws.com
```

In `config/filesystems.php`, ensure the `s3` disk is configured. Livewire will automatically use it for temporary file storage when `FILESYSTEM_DISK=s3`.

**Lando + S3:** Use a local MinIO service in `.lando.yml` to simulate S3 during development:

```yaml
services:
  minio:
    type: minio
    portforward: 9000
    access_key: minioadmin
    secret_key: minioadmin
```

Set `AWS_ENDPOINT=http://minio:9000` in `.env` for the Lando MinIO service.

## Validation Reference

| Rule | Effect |
|---|---|
| `image` | Must be a valid image file (jpg, png, gif, bmp, svg, webp) |
| `max:2048` | Max 2 MB (in kilobytes) |
| `mimes:pdf,docx` | Restrict to specific MIME types |
| `dimensions:min_width=100,min_height=100` | Minimum pixel dimensions |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Storing file objects in public properties between requests | Always `$this->reset('photo')` after saving; files are not serializable |
| Using `wp_handle_upload()` instead of `media_handle_sideload()` for Livewire files | Use `media_handle_sideload()` — Livewire files are already in a temp path |
| Forgetting `storage:link` | Run `lando acorn storage:link` after first deploy |
| No loading state on the upload button | Add `wire:loading.attr="disabled" wire:target="photo"` to prevent double-submit |
