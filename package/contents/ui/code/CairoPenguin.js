.pragma library

/**
 * @typedef {Object} PenguinStateConfig
 * @property {number} [frameRate=10] - Tasa de frames base.
 * @property {number} [frameCount=1] - Cantidad total de frames de la animación.
 * @property {PenguinTag[]} [tags=[]] - Etiquetas que definen el comportamiento ("moving", "action", etc.).
 */

/**
 * @typedef {"basher" | "blocker" | "boarder" | "bomber" | "bridger" | "bridgerWalk" | "digger" | "drownFall" | "drownWalk" | "exit" | "faller" | "floater" | "miner" | "reader" | "rocketLauncher" | "sitter" | "splat" | "superman" | "tumble" | "waiter" | "walker" | "xmasWalker"} PenguinStateName
 */

/**
 * @typedef {"moving" | "action" | "hoverWake" | "oneShot" | "terminal"} PenguinTag
 */

/**
 * Clase que representa un estado individual de la animación del pingüino.
 * Utiliza desestructuración en el constructor para asignar valores por defecto.
 */
class PenguinState {
    /**
     * @param {PenguinStateName} name - el nombre del estado (ej., "basher", "walker").
     * @param {PenguinStateConfig} [config={}] - configuración del estado desestructurada.
     */
    constructor(name, { frameRate = 10, frameCount = 1, tags = [] } = {}) {
        this.name = name;
        this.baseFrameRate = frameRate;
        this.frameCount = frameCount;
        this.tags = new Set(tags);
    }

    /**
     * @returns {boolean} verdadero si el pingüino se desplaza por la pantalla.
     */
    isMoving() {
        return this.tags.has("moving");
    }

    /**
     * @returns {boolean} verdadero si el estado puede ser interrumpido al pasar el ratón.
     */
    isHoverWake() {
        return this.tags.has("hoverWake");
    }

    /**
     * @returns {boolean} verdadero si es una acción especial activada por el temporizador.
     */
    isAction() {
        return this.tags.has("action");
    }

    /**
     * @returns {boolean} verdadero si la animación debe reproducirse solo una vez y bloquear interacciones.
     */
    isOneShot() {
        return this.tags.has("oneShot");
    }

    /**
     * @returns {boolean} verdadero si el estado hace que el pingüino desaparezca al final.
     */
    isTerminal() {
        return this.tags.has("terminal");
    }

    /**
     * Calcula el frame rate dinámico basado en la escala del usuario.
     *
     * @param {number} scale - multiplicador global de velocidad.
     * @returns {number} la tasa de frames final.
     */
    getFrameRateWithScale(scale) {
        return this.baseFrameRate * scale;
    }

    /**
     * Calcula la duración exacta de la animación en milisegundos con un margen de seguridad.
     *
     * @param {number} scale - multiplicador global de velocidad.
     * @returns {number} milisegundos que dura la animación (mínimo 100ms).
     */
    getDurationMs(scale) {
        const effectiveRate = this.getFrameRateWithScale(scale);
        const frameMs = 1000 / effectiveRate;
        const totalMs = this.frameCount * frameMs;

        return Math.max(100, Math.floor(totalMs - (frameMs * 0.25)));
    }
}

/**
 * Mapa de instancias por nombre de estado.
 *
 * @type {Map<PenguinStateName, PenguinState>}
 */
const states = new Map([
    ["basher", new PenguinState("basher", { frameRate: 12, frameCount: 12, tags: ["moving"] })],
    ["blocker", new PenguinState("blocker", { frameRate: 10, frameCount: 6, tags: ["hoverWake"] })],
    ["boarder", new PenguinState("boarder", { frameRate: 1, frameCount: 1, tags: ["moving"] })],
    ["bomber", new PenguinState("bomber", { frameRate: 10, frameCount: 16, tags: ["action", "oneShot"] })],
    ["bridger", new PenguinState("bridger", { frameRate: 15, frameCount: 15, tags: ["moving"] })],
    ["bridgerWalk", new PenguinState("bridgerWalk", { frameRate: 10, frameCount: 4, tags: ["moving"] })],
    ["digger", new PenguinState("digger", { frameRate: 16, frameCount: 14, tags: ["action"] })],
    ["drownFall", new PenguinState("drownFall", { frameRate: 18, frameCount: 15, tags: ["oneShot", "terminal"] })],
    ["drownWalk", new PenguinState("drownWalk", { frameRate: 18, frameCount: 15, tags: ["oneShot", "terminal"] })],
    ["exit", new PenguinState("exit", { frameRate: 6, frameCount: 9, tags: ["action", "oneShot", "terminal"] })],
    ["faller", new PenguinState("faller", { frameRate: 8, frameCount: 8, tags: ["oneShot"] })],
    ["floater", new PenguinState("floater", { frameRate: 8, frameCount: 8, tags: [] })],
    ["miner", new PenguinState("miner", { frameRate: 16, frameCount: 12, tags: ["moving"] })],
    ["reader", new PenguinState("reader", { frameRate: 16, frameCount: 12, tags: ["hoverWake"] })],
    ["rocketLauncher", new PenguinState("rocketLauncher", { frameRate: 10, frameCount: 7, tags: ["moving"] })],
    ["sitter", new PenguinState("sitter", { frameRate: 1, frameCount: 1, tags: ["hoverWake"] })],
    ["splat", new PenguinState("splat", { frameRate: 13, frameCount: 16, tags: ["oneShot"] })],
    ["superman", new PenguinState("superman", { frameRate: 8, frameCount: 8, tags: [] })],
    ["tumble", new PenguinState("tumble", { frameRate: 3, frameCount: 8, tags: ["action", "oneShot"] })],
    ["waiter", new PenguinState("waiter", { frameRate: 8, frameCount: 6, tags: ["hoverWake"] })],
    ["walker", new PenguinState("walker", { frameRate: 10, frameCount: 8, tags: ["moving"] })],
    ["xmasWalker", new PenguinState("xmasWalker", { frameRate: 10, frameCount: 8, tags: ["moving"] })]
]);

/**
 * Calcula las listas una sola vez al cargar la librería.
 *
 * @type {PenguinStateName[]}
 */
const ambientStateNames = Array.from(states.values())
    .filter(state => state.isMoving() || state.isHoverWake())
    .map(({ name }) => name);

const actionStateNames = Array.from(states.values())
    .filter(state => state.isAction())
    .map(({ name }) => name);

/**
 * Comprueba si el string corresponde a un estado registrado.
 *
 * @param {PenguinStateName} name
 * @returns {boolean}
 */
function isValidState(name) {
    return states.has(name);
}

/**
 * Recupera la instancia completa de PenguinState.
 *
 * @param {PenguinStateName} name
 * @returns {PenguinState}
 * @throws {Error} si el estado no existe en el mapa.
 */
function getState(name) {
    if (!states.has(name)) {
        throw new Error(`There's no state named: ${name}`);
    }

    return states.get(name);
}

/**
 * Selecciona un estado aleatorio de la lista de estados ambientales.
 *
 * @returns {PenguinStateName}
 */
function pickRandomAmbient() {
    return _pickRandomFrom(ambientStateNames);
}

/**
 * Selecciona un estado aleatorio de la lista de acciones activas.
 *
 * @returns {PenguinStateName}
 */
function pickRandomAction() {
    return _pickRandomFrom(actionStateNames);
}

/**
 * Función auxiliar interna
 *
 * @param {PenguinStateName[]} stateList
 * @returns {PenguinStateName}
 * @private
 */
function _pickRandomFrom(stateList) {
    if (!stateList || stateList.length === 0) {
        return "";
    }
    if (stateList.length === 1) {
        return stateList[0];
    }

    return stateList[Math.floor(Math.random() * stateList.length)];
}
