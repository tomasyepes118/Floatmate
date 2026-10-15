// Prototipo front-end: los registros se conservan en este navegador.
// Este login es demostrativo y no protege información real.
const initialVehicles = [
  {
    plate: "TPQ482",
    model: "Chevrolet NPR 2024",
    capacity: 32,
    km: 28450,
    status: "Disponible",
  },
  {
    plate: "SXY916",
    model: "Mercedes-Benz LO 2023",
    capacity: 40,
    km: 61400,
    status: "En viaje",
  },
  {
    plate: "WLM305",
    model: "Hino FC 2022",
    capacity: 35,
    km: 89300,
    status: "Mantenimiento",
  },
  {
    plate: "JRC728",
    model: "Chevrolet NQR 2025",
    capacity: 38,
    km: 12300,
    status: "Disponible",
  },
  {
    plate: "KPT641",
    model: "Mercedes-Benz LO 2024",
    capacity: 40,
    km: 31700,
    status: "Disponible",
  },
];
const initialTrips = [
  {
    origin: "Medellín",
    destination: "Rionegro",
    driver: "Carlos Restrepo",
    plate: "TPQ482",
    departure: "2026-10-05T07:30",
    status: "Programado",
  },
  {
    origin: "Bello",
    destination: "Medellín",
    driver: "Laura Gómez",
    plate: "SXY916",
    departure: "2026-10-02T10:00",
    status: "En curso",
  },
  {
    origin: "Medellín",
    destination: "Guatapé",
    driver: "Andrés Ruiz",
    plate: "JRC728",
    departure: "2026-10-06T08:00",
    status: "Programado",
  },
  {
    origin: "Rionegro",
    destination: "Medellín",
    driver: "Daniel López",
    plate: "KPT641",
    departure: "2026-10-01T17:00",
    status: "Finalizado",
  },
];
function load(key, fallback) {
  try {
    const value = JSON.parse(localStorage.getItem(key));
    return Array.isArray(value) ? value : structuredClone(fallback);
  } catch {
    return fallback;
  }
}
let vehicles = load("floatmate_vehicles", initialVehicles),
  trips = load("floatmate_trips", initialTrips);
function save() {
  try {
    localStorage.setItem("floatmate_vehicles", JSON.stringify(vehicles));
    localStorage.setItem("floatmate_trips", JSON.stringify(trips));
  } catch {
    notify(
      "Los cambios funcionan durante esta visita; el navegador no permite guardarlos.",
    );
  }
}
const $ = (id) => document.getElementById(id);
// Escape de texto antes de insertarlo en las tablas.
const esc = (value) =>
  String(value).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
function badge(status) {
  const classes = {
    Disponible: "available",
    Programado: "moving",
    "En viaje": "moving",
    "En curso": "moving",
    Mantenimiento: "maintenance",
    Finalizado: "done",
  };
  return `<span class="status status-${classes[status] || "done"}">${esc(status)}</span>`;
}
const date = (value) =>
  new Date(value).toLocaleString("es-CO", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
function notify(text) {
  if (!$("feedback")) return;
  $("feedback").textContent = text;
  $("feedback").hidden = false;
  setTimeout(() => ($("feedback").hidden = true), 4500);
}
const page = document.body.dataset.page;
document.querySelector(`[data-nav="${page}"]`)?.classList.add("active");
document
  .querySelector(`[data-nav="${page}"]`)
  ?.setAttribute("aria-current", "page");
document.querySelectorAll("[data-open]").forEach((button) =>
  button.addEventListener("click", () => {
    if (button.dataset.open === "trip-dialog") fillVehicles();
    $(button.dataset.open).showModal();
  }),
);
document
  .querySelectorAll("[data-close]")
  .forEach((button) =>
    button.addEventListener("click", () => $(button.dataset.close).close()),
  );
if (page === "login") {
  $("show-password").onclick = () => {
    const hidden = $("clave").type === "password";
    $("clave").type = hidden ? "text" : "password";
    $("show-password").textContent = hidden ? "Ocultar" : "Ver";
    $("show-password").setAttribute(
      "aria-label",
      hidden ? "Ocultar contraseña" : "Mostrar contraseña",
    );
  };
  $("login-form").onsubmit = (event) => {
    event.preventDefault();
    if (
      $("usuario").value.trim() === "admin" &&
      $("clave").value === "floatmate123"
    ) {
      location.href = "dashboard.html";
    } else {
      $("login-error").textContent =
        "Usuario o contraseña incorrectos. Usa los datos de demostración.";
    }
  };
}
function renderVehicles() {
  const q = $("vehicle-search").value.trim().toLowerCase(),
    state = $("vehicle-status").value;
  const list = vehicles.filter(
    (v) =>
      (v.plate + " " + v.model).toLowerCase().includes(q) &&
      (!state || v.status === state),
  );
  $("vehicle-list").innerHTML = list
    .map(
      (v) =>
        `<tr><td><strong>${esc(v.plate)}</strong></td><td>${esc(v.model)}</td><td>${v.capacity} pasajeros</td><td>${v.km.toLocaleString("es-CO")} km</td><td>${badge(v.status)}</td></tr>`,
    )
    .join("");
  $("vehicle-count").textContent = list.length + " vehículos";
  $("vehicle-empty").hidden = list.length > 0;
  labelTables();
}
if (page === "vehiculos") {
  renderVehicles();
  $("vehicle-search").oninput = renderVehicles;
  $("vehicle-status").onchange = renderVehicles;
  $("vehicle-form").onsubmit = (event) => {
    event.preventDefault();
    const plate = $("plate").value.trim().toUpperCase(),
      model = $("model").value.trim();
    if (!model) {
      $("vehicle-error").textContent = "Escribe el modelo del vehículo.";
      return;
    }
    if (vehicles.some((v) => v.plate === plate)) {
      $("vehicle-error").textContent = "Esta placa ya está registrada.";
      return;
    }
    vehicles.push({
      plate,
      model,
      capacity: Number($("capacity").value),
      km: Number($("km").value),
      status: $("new-status").value,
    });
    save();
    renderVehicles();
    $("vehicle-dialog").close();
    $("vehicle-form").reset();
    $("vehicle-error").textContent = "";
    notify("Vehículo registrado correctamente.");
  };
}
function fillVehicles() {
  const available = vehicles.filter((v) => v.status === "Disponible");
  $("trip-vehicle").innerHTML =
    '<option value="">Selecciona un vehículo</option>' +
    available
      .map(
        (v) =>
          `<option value="${esc(v.plate)}">${esc(v.plate)} · ${v.capacity} pasajeros</option>`,
      )
      .join("");
  if (!available.length)
    $("trip-error").textContent = "No hay vehículos disponibles.";
  else $("trip-error").textContent = "";
}
function renderTrips() {
  const q = $("trip-search").value.trim().toLowerCase(),
    state = $("trip-status").value;
  const list = trips
    .filter(
      (t) =>
        (t.origin + " " + t.destination + " " + t.driver)
          .toLowerCase()
          .includes(q) &&
        (!state || t.status === state),
    )
    .sort((a, b) => a.departure.localeCompare(b.departure));
  $("trip-list").innerHTML = list
    .map(
      (t) =>
        `<tr><td><strong>${esc(t.origin)} - ${esc(t.destination)}</strong></td><td>${esc(t.driver)}</td><td>${esc(t.plate)}</td><td>${date(t.departure)}</td><td>${badge(t.status)}</td></tr>`,
    )
    .join("");
  $("trip-count").textContent = list.length + " viajes";
  $("trip-empty").hidden = list.length > 0;
  labelTables();
}
if (page === "viajes") {
  renderTrips();
  $("trip-search").oninput = renderTrips;
  $("trip-status").onchange = renderTrips;
  $("trip-form").onsubmit = (event) => {
    event.preventDefault();
    const origin = $("origin").value.trim(),
      destination = $("destination").value.trim(),
      driver = $("driver").value.trim();
    if (!origin || !destination || !driver) {
      $("trip-error").textContent =
        "Completa los campos con información válida.";
      return;
    }
    if (origin.toLowerCase() === destination.toLowerCase()) {
      $("trip-error").textContent =
        "El origen y el destino deben ser diferentes.";
      return;
    }
    const departure = $("departure").value;
    if (new Date(departure) <= new Date()) {
      $("trip-error").textContent = "Selecciona una fecha y hora futuras.";
      return;
    }
    const plate = $("trip-vehicle").value;
    if (
      trips.some(
        (t) =>
          t.plate === plate &&
          t.departure === departure &&
          t.status !== "Finalizado",
      )
    ) {
      $("trip-error").textContent =
        "Este vehículo ya tiene un viaje a esa hora.";
      return;
    }
    trips.push({
      origin,
      destination,
      driver,
      plate,
      departure,
      status: "Programado",
    });
    save();
    renderTrips();
    $("trip-dialog").close();
    $("trip-form").reset();
    notify("Viaje programado correctamente.");
  };
}
if (page === "dashboard") {
  $("total-vehicles").textContent = vehicles.length;
  $("available-vehicles").textContent = vehicles.filter(
    (v) => v.status === "Disponible",
  ).length;
  $("maintenance-vehicles").textContent = vehicles.filter(
    (v) => v.status === "Mantenimiento",
  ).length;
  $("scheduled-trips").textContent = trips.filter(
    (t) => t.status === "Programado",
  ).length;
  const list = trips
    .filter((t) => t.status === "Programado")
    .sort((a, b) => a.departure.localeCompare(b.departure))
    .slice(0, 4);
  $("dashboard-trips").innerHTML =
    list
      .map(
        (t) =>
          `<tr><td><strong>${esc(t.origin)} - ${esc(t.destination)}</strong><small>${esc(t.driver)}</small></td><td>${date(t.departure)}</td><td>${esc(t.plate)}</td><td>${badge(t.status)}</td></tr>`,
      )
      .join("") || '<tr><td colspan="4">No hay viajes programados.</td></tr>';
  $("fleet-status").innerHTML = ["Disponible", "En viaje", "Mantenimiento"]
    .map((state) => {
      const n = vehicles.filter((v) => v.status === state).length;
      return `<div class="state-row"><div><span>${state}</span><strong>${n}</strong></div><div class="progress" role="progressbar" aria-label="${state}" aria-valuenow="${n}" aria-valuemin="0" aria-valuemax="${vehicles.length}"><div class="progress-bar" style="width:${vehicles.length ? (n / vehicles.length) * 100 : 0}%"></div></div></div>`;
    })
    .join("");
}

// Las etiquetas identifican cada valor en la vista móvil.
function labelTables() {
  document.querySelectorAll("table").forEach((table) => {
    const labels = [...table.querySelectorAll("thead th")].map(
      (th) => th.textContent,
    );
    table
      .querySelectorAll("tbody tr")
      .forEach((row) =>
        [...row.cells].forEach(
          (cell, i) => (cell.dataset.label = labels[i] || ""),
        ),
      );
  });
}
labelTables();
