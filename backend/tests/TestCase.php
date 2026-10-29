<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;

abstract class TestCase extends BaseTestCase
{
    private string $directorioPrueba;

    protected function setUp(): void
    {
        parent::setUp();
        $this->directorioPrueba = sys_get_temp_dir().DIRECTORY_SEPARATOR.'floatmate-pruebas-'.Str::uuid();
        config(['demo.directorio'=>$this->directorioPrueba]);
    }

    protected function tearDown(): void
    {
        if (isset($this->directorioPrueba) && str_starts_with($this->directorioPrueba, sys_get_temp_dir().DIRECTORY_SEPARATOR.'floatmate-pruebas-')) {
            File::deleteDirectory($this->directorioPrueba);
        }
        parent::tearDown();
    }
}
