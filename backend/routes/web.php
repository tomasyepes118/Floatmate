<?php

use App\Http\Controllers\AccesoController;
use App\Http\Controllers\ResumenController;
use App\Http\Controllers\OperacionesController;
use Illuminate\Support\Facades\Route;

// El grupo web aporta cookies, sesión y protección CSRF; no se usa base de datos.
Route::prefix('api')->group(function (): void {
    Route::get('/csrf', fn () => response()->json(['token' => csrf_token()])->header('Cache-Control', 'no-store'));
    Route::post('/login', [AccesoController::class, 'ingresar'])->middleware('throttle:5,1,acceso');

    Route::middleware('sesion.demo')->group(function (): void {
        Route::get('/sesion', [AccesoController::class, 'sesion']);
        Route::post('/logout', [AccesoController::class, 'salir']);
        Route::get('/resumen', ResumenController::class);
        Route::get('/vehiculos', [OperacionesController::class, 'vehiculos']);
        Route::post('/vehiculos', [OperacionesController::class, 'guardarVehiculo'])->middleware('throttle:60,1,operaciones');
        Route::get('/viajes', [OperacionesController::class, 'viajes']);
        Route::post('/viajes', [OperacionesController::class, 'guardarViaje'])->middleware('throttle:60,1,operaciones');
    });
});
