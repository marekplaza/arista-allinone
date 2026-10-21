# arista-allinone

Kontener narzędziowy do labów Arista. Po wejściu do shella masz od razu:

- **containerlab** (najnowszy w chwili budowy),
- **Arista AVD**: `pyavd` + kolekcja `arista.avd` w tej samej wersji, pełny pakiet **Ansible** (wszystkie kolekcje community) oraz `arista.eos` i `arista.cvp`,
- **ANTA** (`anta[cli]`),
- **get_ceos**: pobieranie i import obrazu cEOS-lab (cEOS / cEOS64 / cEOSarm),
- cele `make` takie jak w [cvaas_avd_L2LS](https://github.com/marekplaza/cvaas_avd_L2LS) (`mk help`),
- Docker CLI, `eos-downloader` (`ardl`), `ansible-lint`, `yamllint`, `sshpass`, `jq`.

Obraz działa na amd64 i arm64 (Apple Silicon).

## Wersje (build z 2026-10-21)

| Narzędzie | Wersja |
|---|---|
| containerlab | 0.81.1 |
| pyavd / arista.avd | 6.4.0 |
| ansible-core / ansible | 2.21.5 / 14.5.0 |
| arista.eos / arista.cvp | 12.3.0 / 3.9.0 |
| ANTA | 1.10.0 |

Bez argumentów build bierze najnowsze wersje. Konkretne wersje przypniesz tak:

```bash
docker build -t arista-allinone \
  --build-arg CLAB_VERSION=0.81.1 --build-arg AVD_VERSION=6.4.0 --build-arg ANTA_VERSION=1.10.0 .
```

## Szybki start

```bash
git clone https://github.com/marekplaza/arista-allinone.git && cd arista-allinone
cp .env.example .env          # uzupełnij ARISTA_TOKEN (i CV_API_TOKEN dla CVaaS)
make image                    # docker build
make shell LAB_DIR=~/lab      # kontener z podmontowanym katalogiem labu
```

`make shell` uruchamia odpowiednik tego polecenia:

```bash
docker run -it --rm --name allinone \
  --privileged --network host --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME/lab":"$HOME/lab" -w "$HOME/lab" \
  --env-file .env \
  arista-allinone:latest
```

Katalog labu montuj **pod tą samą ścieżką** co na hoście. Containerlab przekazuje ścieżki bind-mountów (startup-config, pliki węzłów) demonowi Dockera hosta, więc przy innej ścieżce węzły nie znajdą swoich plików.

## W kontenerze

```bash
mk init        # skopiuj lab referencyjny L2LS (clab/ + avd_inventory/) do bieżącego katalogu
mk ceos        # pobierz najnowszy cEOS-lab (arm64 na Apple Silicon) i otaguj :latest
mk start       # containerlab deploy
mk build       # AVD: generowanie configów i dokumentacji
mk deploy      # AVD: wdrożenie przez eAPI
mk test        # walidacja stanu sieci (ANTA przez AVD)
mk stop        # containerlab destroy
```

| Cel | Działanie |
|---|---|
| `init` | kopiuje lab referencyjny z `/opt/cvaas_avd_L2LS` |
| `start` / `stop` / `inspect` / `graph` | containerlab deploy / destroy / inspect / graf (port 50080) |
| `build` / `deploy` / `diff` / `test` | AVD: build, wdrożenie eAPI, diff (check mode), walidacja |
| `deploy_cvp` / `decommission_cvp` | wdrożenie przez CloudVision / usunięcie urządzeń z CVaaS |
| `anta` | ANTA NRFU bezpośrednio (`ANTA_INV`, `ANTA_CAT`) |
| `ceos` / `ceos-list` | pobranie i import cEOS / lista lokalnych obrazów |
| `versions` | wersje narzędzi |

Domyślne ścieżki są takie jak w cvaas_avd_L2LS: `clab/topology.clab.yml` i `avd_inventory/`. Nadpiszesz je zmiennymi, np. `mk start TOPO=lab.clab.yml` albo `mk build AVD_DIR=ansible`.
Jeśli katalog labu ma własny `Makefile`, zwykłe `make` też działa.

## Obraz cEOS (get_ceos)

`get_ceos.sh` pochodzi z cvaas_avd_L2LS i używa `curl` zamiast `ardl`, bo arista.com odpowiada klientom HTTP z Pythona stroną „Client Challenge”. Dodana jest opcja `-a` (cEOSarm-lab dla arm64).

```bash
mk ceos                          # najnowsze M, architektura wykrywana automatycznie
mk ceos CEOS_REL=F               # najnowsze F
mk ceos CEOS_VER=4.35.1F         # konkretna wersja
get_ceos -a -v 4.35.1F -t latest # bezpośrednio, opcje: get_ceos -h
```

Obrazy są tagowane jako `arista/ceos:<wersja>`, `arista/ceos64:<wersja>` albo `arista/ceosarm:<wersja>`. Tag z `-t` dodaje drugi tag (domyślnie w `mk ceos`: `latest`). W topologii ustaw `image:` na ten sam tag.

## Bezpieczeństwo

- Tokeny (`ARISTA_TOKEN`, `CV_API_TOKEN`) podawaj tylko przez zmienne środowiskowe lub `.env`. `.env` jest w `.gitignore`.
- Kontener działa jako `--privileged` z dostępem do `docker.sock`, czyli ma pełną kontrolę nad Dockerem hosta. Używaj go tylko w środowisku labowym.
- Na macOS `--network host` oznacza sieć maszyny wirtualnej Docker Desktop. Adresy mgmt węzłów są osiągalne z kontenera allinone, ale z macOS bezpośrednio nie zawsze.

## Struktura

```
Dockerfile      obraz
Makefile        cele po stronie hosta: image, image-nocache, shell, versions
lab/Makefile    cele labowe w kontenerze (alias mk)
lab/bashrc      aliasy i baner powłoki
get_ceos.sh     pobieranie cEOS-lab
.env.example    szablon zmiennych
```
