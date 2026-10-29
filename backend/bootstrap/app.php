<?php

use App\Http\Middleware\RequiereSesionDemo;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(web: __DIR__.'/../routes/web.php', commands: __DIR__.'/../routes/console.php', health: '/up')
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias(['sesion.demo' => RequiereSesionDemo::class]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(fn (Request $request, Throwable $exception) => $request->is('api/*'));
        $exceptions->render(function (Illuminate\Validation\ValidationException $exception, Request $request) {
            if ($request->is('api/*')) {
                $errores = $exception->errors();
                return response()->json(['message' => collect($errores)->flatten()->first(), 'errors' => $errores], 422);
            }
        });
    })->create();
