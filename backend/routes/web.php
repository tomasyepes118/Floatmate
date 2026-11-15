<?php

use App\Http\Controllers\AccesoController;
use App\Http\Controllers\AccesosOperativosController;
use App\Http\Controllers\ResumenController;
use App\Http\Controllers\OperacionesController;
use App\Http\Controllers\CatalogosController;
use App\Http\Controllers\GeografiaController;
use App\Http\Controllers\MisViajesController;
use App\Http\Controllers\RegistrosController;
use Illuminate\Support\Facades\Route;

// El grupo web aporta cookies, sesión y protección CSRF.
Route::prefix('api')->group(function (): void {
    Route::get('/csrf', fn () => response()->json(['token' => csrf_token()])->header('Cache-Control', 'no-store'));
    Route::post('/login', [AccesoController::class, 'ingresar'])->middleware('throttle:5,1,acceso');

    Route::middleware('sesion.demo')->group(function (): void {
        Route::get('/sesion', [AccesoController::class, 'sesion']);
        Route::post('/logout', [AccesoController::class, 'salir']);
        Route::get('/resumen', ResumenController::class)->middleware('rol.operativo:Administrador,Operador,Consulta');
        Route::get('/mis-viajes', [MisViajesController::class, 'index'])->middleware('rol.operativo:Conductor');
        Route::get('/accesos', [AccesosOperativosController::class, 'index'])->middleware('rol.operativo:Administrador');
        Route::middleware('rol.operativo:Administrador,Operador')->group(function (): void {
            Route::get('/vehiculos', [OperacionesController::class, 'vehiculos']);
            Route::get('/viajes', [OperacionesController::class, 'viajes']);
            Route::get('/registros', [RegistrosController::class, 'index']);
            Route::get('/registros/combustible/acpm', [RegistrosController::class, 'precioAcpm'])->middleware('throttle:30,1,consulta-acpm');
        });
        Route::get('/catalogos', [CatalogosController::class, 'index'])->middleware('rol.operativo:Administrador');
        Route::get('/municipios/antioquia', [GeografiaController::class, 'municipios'])->middleware('rol.operativo:Administrador');
        Route::get('/registros/{tipo}/csv', [RegistrosController::class, 'exportar'])
            ->whereIn('tipo', RegistrosController::TIPOS)->middleware('rol.operativo:Administrador,Operador,Consulta');

        Route::middleware('throttle:60,1,operaciones')->group(function (): void {
            Route::middleware('rol.operativo:Administrador')->group(function (): void {
                Route::post('/accesos', [AccesosOperativosController::class, 'crear']);
                Route::patch('/accesos/{usuario}', [AccesosOperativosController::class, 'actualizar'])->where('usuario', '[a-z0-9][a-z0-9._-]{2,59}');
                Route::post('/vehiculos', [OperacionesController::class, 'guardarVehiculo']);
                Route::put('/vehiculos/{id}', [OperacionesController::class, 'guardarVehiculo'])->whereNumber('id');
                Route::post('/catalogos/{tipo}', [CatalogosController::class, 'guardar'])->whereIn('tipo', CatalogosController::TIPOS);
                Route::post('/catalogos/rutas/estimar', [GeografiaController::class, 'estimar']);
                Route::put('/catalogos/{tipo}/{id}', [CatalogosController::class, 'guardar'])->whereIn('tipo', CatalogosController::TIPOS)->whereNumber('id');
            });
            Route::middleware('rol.operativo:Administrador,Operador')->group(function (): void {
                Route::post('/viajes', [OperacionesController::class, 'guardarViaje']);
                Route::post('/viajes/elegibilidad', [OperacionesController::class, 'revisarElegibilidad']);
                Route::post('/viajes/{id}/control', [OperacionesController::class, 'registrarControl'])->whereNumber('id');
                Route::patch('/viajes/{id}/estado', [OperacionesController::class, 'cambiarEstadoViaje'])->whereNumber('id');
                Route::post('/registros/{tipo}', [RegistrosController::class, 'guardar'])->whereIn('tipo', RegistrosController::TIPOS);
            });
            Route::middleware('rol.operativo:Conductor')->prefix('/mis-viajes/{id}')->where(['id'=>'[0-9]+'])->group(function (): void {
                Route::post('/confirmar', [MisViajesController::class, 'confirmar']);
                Route::patch('/llegada', [OperacionesController::class, 'registrarLlegadaPropia']);
                Route::post('/incidentes', [RegistrosController::class, 'reportarIncidentePropio']);
            });
        });
    });
});
