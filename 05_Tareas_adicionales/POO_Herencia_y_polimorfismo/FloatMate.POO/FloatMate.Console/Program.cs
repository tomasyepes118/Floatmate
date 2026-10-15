using FloatMate.Application;
using FloatMate.Domain.Enums;
using FloatMate.Domain.Models;
using FloatMate.Domain.Vehiculos;

// Equipo desarrollador:
// Tomás Yepes
// Cristian Benites
// Mateo Gallo

List<VehiculoFlota> vehiculos =
[
    new BusUrbano("BUS-01", "TMA101", 40, 48_200, 50_000, 8.5m),
    new BusUrbano("BUS-02", "TMA102", 42, 31_400, 35_000, 8.2m),
    new BusUrbano("BUS-03", "TMA103", 40, 62_900, 65_000, 8.7m),
    new BusUrbano("BUS-04", "TMA104", 38, 27_600, 30_000, 8.9m),
    new BusIntermunicipal("BUS-05", "TMB205", 36, 71_300, 75_000, 10.5m),
    new BusIntermunicipal("BUS-06", "TMB206", 36, 53_700, 58_000, 10.2m),
    new Microbus("BUS-07", "TMC307", 19, 22_100, 25_000, 13.8m),
    new Microbus("BUS-08", "TMC308", 19, 18_900, 22_000, 14.1m)
];

vehiculos[3].CambiarEstado(EstadoVehiculo.Mantenimiento);

GestorFlota gestor = new(vehiculos);

Ruta rutaUrbana = new(
    "Centro - Terminal",
    TipoRuta.Urbana,
    distanciaKm: 32,
    pasajerosEsperados: 18,
    paradasProgramadas: 14);

Ruta rutaIntermunicipal = new(
    "Terminal - Municipio Norte",
    TipoRuta.Intermunicipal,
    distanciaKm: 118,
    pasajerosEsperados: 30,
    paradasProgramadas: 4);

Console.WriteLine("FLOATMATE - DEMOSTRACIÓN DE HERENCIA Y POLIMORFISMO");
Console.WriteLine("Equipo: Tomás Yepes, Cristian Benites y Mateo Gallo");

MostrarEvaluacion(gestor, rutaUrbana);
MostrarEvaluacion(gestor, rutaIntermunicipal);

static void MostrarEvaluacion(GestorFlota gestor, Ruta ruta)
{
    Console.WriteLine();
    Console.WriteLine($"Ruta: {ruta.Nombre} | Tipo: {ruta.Tipo} | Distancia: {ruta.DistanciaKm:N0} km");
    Console.WriteLine(new string('-', 100));
    Console.WriteLine($"{"Código",-10} {"Tipo",-22} {"Resultado",-11} {"ACPM",8}  Motivo");
    Console.WriteLine(new string('-', 100));

    foreach (ResultadoAsignacion resultado in gestor.EvaluarRuta(ruta))
    {
        string estado = resultado.Aprobada ? "Aprobado" : "Rechazado";
        string consumo = resultado.Aprobada ? $"{resultado.ConsumoAcpmEstimado:N2}" : "-";

        Console.WriteLine(
            $"{resultado.CodigoVehiculo,-10} {resultado.TipoVehiculo,-22} {estado,-11} {consumo,8}  {resultado.Motivo}");
    }

    ResultadoAsignacion? seleccion = gestor.SeleccionarMejorOpcion(ruta);
    Console.WriteLine();

    if (seleccion is null)
    {
        Console.WriteLine("No existe un vehículo apto para la ruta.");
        return;
    }

    Console.WriteLine(
        $"Mejor opción: {seleccion.CodigoVehiculo} ({seleccion.TipoVehiculo}), " +
        $"consumo estimado {seleccion.ConsumoAcpmEstimado:N2} galones.");
}
