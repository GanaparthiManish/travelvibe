const API = 'http://localhost:3001/api';

export async function fetchData() {
  const res = await fetch(`${API}/data`);
  return res.json();
}

export async function patchSplash(splash) {
  await fetch(`${API}/splash`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(splash),
  });
}

export async function putCategories(cats) {
  await fetch(`${API}/categories`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(cats),
  });
}

export async function postDestination(dest) {
  const res = await fetch(`${API}/destinations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(dest),
  });
  return res.json();
}

export async function putDestination(id, dest) {
  await fetch(`${API}/destinations/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(dest),
  });
}

export async function deleteDestination(id) {
  await fetch(`${API}/destinations/${id}`, { method: 'DELETE' });
}

export async function postAgent(agent) {
  const res = await fetch(`${API}/agents`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(agent),
  });
  return res.json();
}

export async function putAgent(id, agent) {
  await fetch(`${API}/agents/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(agent),
  });
}

export async function deleteAgent(id) {
  await fetch(`${API}/agents/${id}`, { method: 'DELETE' });
}
