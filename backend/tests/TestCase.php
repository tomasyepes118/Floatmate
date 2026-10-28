<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    // Sin RefreshDatabase: esta aplicación no usa una base de datos.
}
