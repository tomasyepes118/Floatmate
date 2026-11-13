<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('flota_operativa', function (Blueprint $table): void {
            $table->smallInteger('id')->primary();
            $table->jsonb('datos');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('flota_operativa');
    }
};
