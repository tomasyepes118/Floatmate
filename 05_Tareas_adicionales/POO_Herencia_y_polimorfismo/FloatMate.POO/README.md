# FloatMate Entregable 3

Proyecto de consola en C# y .NET que aplica herencia, clases abstractas, métodos virtuales, sobrescritura, interfaces y polimorfismo al proceso de asignación de vehículos de una flota.

## Equipo

- Tomás Yepes
- Cristian Benites
- Mateo Gallo

## Ejecución

1. Abra `FloatMate.POO.sln` en Visual Studio 2022.
2. Restaure la solución si Visual Studio lo solicita.
3. Ejecute el proyecto `FloatMate.Console`.

También puede ejecutarse desde una terminal con el SDK de .NET 8:

```text
dotnet run --project FloatMate.Console/FloatMate.Console.csproj
```

## Organización

- `Domain/Vehiculos`: clase abstracta y clases derivadas.
- `Domain/Interfaces`: contrato de mantenimiento.
- `Domain/Models`: ruta y resultado de asignación.
- `Domain/Enums`: estados y tipos de ruta.
- `Application`: servicio que procesa la flota de forma polimórfica.
- `Program.cs`: única capa que escribe en consola.

Las clases de negocio no contienen llamadas a `Console.WriteLine` ni `Console.ReadLine`.
