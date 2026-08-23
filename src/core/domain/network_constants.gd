## @file network_constants.gd
## @path res://src/core/domain/network_constants.gd
##
## @description
## Constantes de domínio compartilhadas para configuração e topologia de rede.
## Fonte única da verdade para portas padrão, limites, segredos e modos de serialização.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name NetworkConstants
extends RefCounted

# ==============================================================================
# CONSTANTES DE REDE E ENDEREÇAMENTO
# ==============================================================================

const DEFAULT_PORT: int = 4242
const DEFAULT_BIND_IP: String = "0.0.0.0"
const DEFAULT_SERVER_IP: String = "127.0.0.1"
const DEFAULT_SECRET: String = "l2-secret"
const DEFAULT_MAX_PEERS: int = 32
const DEFAULT_ENABLE_DTLS: bool = false

# ==============================================================================
# PARÂMETROS DE SIMULAÇÃO E SERIALIZAÇÃO
# ==============================================================================

const DEFAULT_SERVER_TICK_RATE: float = 20.0
const DEFAULT_MAX_STRIKES: int = 9999
const POSITION_MODE_FLOAT32: int = 0
const DEFAULT_WORLD_BOUNDS: float = 2000.0
const DEFAULT_CULL_RADIUS: float = 500.0
const DEFAULT_ENTITY_AURA: float = 500.0
const INVALID_PEER_ID: int = 0

# ==============================================================================
# CHAVES DE CONFIGURAÇÃO DO QUANTICNET
# ==============================================================================

const AUTOLOAD_NAME: String = "QuanticNet"
const KEY_ENABLE_DTLS: String = "enable_dtls"
const KEY_SERVER_TICK_RATE: String = "server_tick_rate"
const KEY_MAX_STRIKES: String = "max_strikes"
const KEY_POSITION_MODE: String = "position_mode"
const KEY_WORLD_BOUNDS: String = "world_bounds"
const KEY_CULL_RADIUS: String = "default_cull_radius"
const KEY_ENTITY_AURA: String = "default_entity_aura"
