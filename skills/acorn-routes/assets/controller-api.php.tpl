<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class {{CLASS_NAME}} extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request): JsonResponse
    {
        // $items = SomeModel::paginate($request->integer('per_page', 15));
        return response()->json([]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            // 'field' => ['required', 'string', 'max:255'],
        ]);

        // $item = SomeModel::create($validated);

        return response()->json(/* $item */, 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(int $id): JsonResponse
    {
        // $item = SomeModel::findOrFail($id);
        return response()->json([]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate([
            // 'field' => ['sometimes', 'string', 'max:255'],
        ]);

        // SomeModel::findOrFail($id)->update($validated);

        return response()->json([]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(int $id): JsonResponse
    {
        // SomeModel::findOrFail($id)->delete();

        return response()->json(status: 204);
    }
}
