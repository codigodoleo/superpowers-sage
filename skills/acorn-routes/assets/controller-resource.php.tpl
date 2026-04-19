<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;

class {{CLASS_NAME}} extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(): View
    {
        return view('{{VIEW_PREFIX}}.index');
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create(): View
    {
        return view('{{VIEW_PREFIX}}.create');
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            // 'field' => ['required', 'string', 'max:255'],
        ]);

        // {{CLASS_NAME}}::create($validated);

        return redirect()->route('{{ROUTE_PREFIX}}.index')
            ->with('success', 'Created successfully.');
    }

    /**
     * Display the specified resource.
     */
    public function show(int $id): View
    {
        // $model = {{CLASS_NAME}}::findOrFail($id);
        return view('{{VIEW_PREFIX}}.show');
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(int $id): View
    {
        // $model = {{CLASS_NAME}}::findOrFail($id);
        return view('{{VIEW_PREFIX}}.edit');
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            // 'field' => ['sometimes', 'string', 'max:255'],
        ]);

        // {{CLASS_NAME}}::findOrFail($id)->update($validated);

        return redirect()->route('{{ROUTE_PREFIX}}.show', $id)
            ->with('success', 'Updated successfully.');
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(int $id): RedirectResponse
    {
        // {{CLASS_NAME}}::findOrFail($id)->delete();

        return redirect()->route('{{ROUTE_PREFIX}}.index')
            ->with('success', 'Deleted successfully.');
    }
}
