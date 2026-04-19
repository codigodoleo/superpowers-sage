<?php

namespace App\Livewire;

use Livewire\Component;
// use Livewire\WithPagination;  // uncomment if this component needs pagination

class {{CLASS_NAME}} extends Component
{
    // use WithPagination;

    public string ${{PROPERTY}} = '';

    /**
     * Runs once when the component is first rendered.
     * Receive initial data from the Blade tag attributes here.
     */
    public function mount(): void
    {
        // wp_set_current_user(get_current_user_id()); // uncomment if WP user context is needed
    }

    public function render(): \Illuminate\View\View
    {
        return view('livewire.{{VIEW_SLUG}}');
    }
}
