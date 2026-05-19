<script>
  import { onMount } from 'svelte';

  let query = '';
  let datasets = [];
  let sources = [];
  let selectedSource = '';
  let selectedVersion = '';

  let options = [];
  let datasetCounts = {};
  let lastUpdate = '';
  let loading = false;
  let error = '';
  let expandedTitles = new Set();
  let page = 1;
  const pageSize = 50;
  let initialized = false;
  let lastLoadedKey = '';

  const keyOf = (source, version) => `${source}::${version}`;
  const baseUrl = import.meta.env.BASE_URL || '/';
  const dataUrl = (name) => `${baseUrl}data/${name}`;

  function applyStateFromUrl() {
    const params = new URLSearchParams(window.location.search);
    const source = params.get('source') || '';
    const version = params.get('version') || '';
    const q = params.get('q');

    if (q != null) query = q;
    if (sources.includes(source)) {
      selectedSource = source;
      const sourceVersions = versionsForSource(source);
      selectedVersion = sourceVersions.includes(version) ? version : defaultVersionForSource(source);
    }
  }

  function syncUrlState() {
    if (!initialized) return;
    const params = new URLSearchParams();
    if (selectedSource) params.set('source', selectedSource);
    if (selectedVersion) params.set('version', selectedVersion);
    if (query) params.set('q', query);
    const qs = params.toString();
    const next = `${window.location.pathname}${qs ? `?${qs}` : ''}`;
    window.history.replaceState(null, '', next);
  }

  async function loadUiConfig() {
    const res = await fetch(dataUrl('ui-config.json'));
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const cfg = await res.json();
    datasets = cfg.datasets || [];
    sources = [...new Set(datasets.map((d) => d.source))];
    selectedSource = sources[0] || '';
    selectedVersion = defaultVersionForSource(selectedSource);
    applyStateFromUrl();
  }

  function versionsForSource(source) {
    return [...new Set(datasets.filter((d) => d.source === source).map((d) => d.version))];
  }

  function defaultVersionForSource(source) {
    const versions = versionsForSource(source);
    if (versions.includes('unstable')) return 'unstable';
    return versions[0] || '';
  }

  async function loadCounts() {
    const pairs = await Promise.all(
      datasets.map(async (d) => {
        try {
          const res = await fetch(dataUrl(d.file));
          if (!res.ok) return [keyOf(d.source, d.version), 0];
          const data = await res.json();
          return [keyOf(d.source, d.version), (data.options || []).length];
        } catch {
          return [keyOf(d.source, d.version), 0];
        }
      })
    );
    datasetCounts = Object.fromEntries(pairs);
  }

  async function loadOptions(source, version) {
    const ds = datasets.find((d) => d.source === source && d.version === version);
    if (!ds) {
      options = [];
      lastUpdate = '';
      return;
    }

    loading = true;
    error = '';
    expandedTitles = new Set();
    try {
      const res = await fetch(dataUrl(ds.file));
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      options = data.options || [];
      lastUpdate = data.last_update || '';
      datasetCounts = { ...datasetCounts, [keyOf(source, version)]: options.length };
    } catch (e) {
      options = [];
      error = `Failed to load ${ds.file} (${e.message})`;
    } finally {
      loading = false;
    }
  }

  function selectSource(source) {
    selectedSource = source;
    selectedVersion = defaultVersionForSource(source);
    page = 1;
    expandedTitles = new Set();
  }

  function selectVersion(version) {
    selectedVersion = version;
    page = 1;
    expandedTitles = new Set();
  }

  function toggleOption(title) {
    if (expandedTitles.has(title)) {
      expandedTitles.delete(title);
    } else {
      expandedTitles.add(title);
    }
    expandedTitles = new Set(expandedTitles);
  }

  $: availableVersions = versionsForSource(selectedSource);
  $: selectedVersion = availableVersions.includes(selectedVersion)
    ? selectedVersion
    : (defaultVersionForSource(selectedSource) || '');

  $: sourceBadge = Object.fromEntries(
    sources.map((s) => {
      const versionForCount = s === selectedSource ? selectedVersion : defaultVersionForSource(s);
      return [s, `${datasetCounts[keyOf(s, versionForCount)] || 0}`];
    })
  );

  $: normalizedQuery = query.trim().toLowerCase();
  $: filteredAll = options.filter((o) => o.title.toLowerCase().includes(normalizedQuery));
  $: totalFiltered = filteredAll.length;
  $: totalPages = Math.max(1, Math.ceil(totalFiltered / pageSize));
  $: page = Math.min(page, totalPages);
  $: startIndex = totalFiltered === 0 ? 0 : (page - 1) * pageSize + 1;
  $: endIndex = Math.min(page * pageSize, totalFiltered);
  $: filtered = filteredAll.slice((page - 1) * pageSize, page * pageSize);

  $: if (selectedSource && selectedVersion) {
    const loadKey = `${selectedSource}::${selectedVersion}`;
    if (loadKey !== lastLoadedKey) {
      lastLoadedKey = loadKey;
      loadOptions(selectedSource, selectedVersion);
    }
  }

  $: syncUrlState();

  onMount(async () => {
    try {
      await loadUiConfig();
      await loadCounts();
      initialized = true;
      syncUrlState();
    } catch (e) {
      error = `Failed to load ui config (${e.message})`;
    }
  });
</script>

<div class="page">
  <main class="container">
    <div class="search-row">
      <input bind:value={query} placeholder="Search options..." on:input={() => (page = 1)} />
      <button type="button">Search</button>
    </div>

    <div class="channels">
      <span>Versions:</span>
      {#each availableVersions as version}
        <button type="button" class="chip {selectedVersion === version ? 'filled' : ''}" on:click={() => selectVersion(version)}>{version}</button>
      {/each}
    </div>

    <section class="content">
      <aside class="card">
        <h3>Source</h3>
        {#each sources as source}
          <button type="button" class="source-row {selectedSource === source ? 'active' : ''}" on:click={() => selectSource(source)}>
            <span>{source}</span>
            <span class="badge">{sourceBadge[source] || '0'}</span>
          </button>
        {/each}
      </aside>

      <div class="results">
        <div class="result-header">
          <h2>Showing results {startIndex}-{endIndex} of <strong>{totalFiltered} options.</strong></h2>
          <button class="sort" type="button">Sort: Best match ▾</button>
        </div>
        <p class="meta">{#if lastUpdate}Data updated {lastUpdate}. {/if}{#if loading}Loading...{/if}{#if error}{error}{/if}</p>

        <ul>
          {#each filtered as option}
            <li>
              <a href="#" on:click|preventDefault={() => toggleOption(option.title)}>{option.title}</a>
              {#if expandedTitles.has(option.title)}
                <div class="details">
                  <div class="detail-row"><span>Name</span><code>{option.title}</code></div>
                  <div class="detail-row"><span>Description</span><p>{option.description || '-'}</p></div>
                  <div class="detail-row"><span>Type</span><p>{option.type || '-'}</p></div>
                  <div class="detail-row"><span>Default</span><code>{option.default || '-'}</code></div>
                  <div class="detail-row"><span>Declared in</span><a href={option.declarations?.[0]?.url || '#'}>{option.declarations?.[0]?.name || '-'}</a></div>
                </div>
              {/if}
            </li>
          {/each}
        </ul>

        <div class="pager">
          <button type="button" on:click={() => (page = Math.max(1, page - 1))} disabled={page <= 1}>Prev</button>
          <span>Page {page} / {totalPages}</span>
          <button type="button" on:click={() => (page = Math.min(totalPages, page + 1))} disabled={page >= totalPages}>Next</button>
        </div>
      </div>
    </section>
  </main>
</div>
