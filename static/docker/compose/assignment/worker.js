/**
 * Worker de RabbitMQ per a Sports Club
 *
 * Aquest worker consumeix missatges de la cua 'tasks' de RabbitMQ
 * i els processa. En aquesta versió de demostració, simplement
 * mostra els missatges per consola.
 *
 * Variables d'entorn requerides:
 * - RABBITMQ_HOST: Host de RabbitMQ (per defecte: localhost)
 * - RABBITMQ_PORT: Port de RabbitMQ (per defecte: 5672)
 * - RABBITMQ_USER: Usuari de RabbitMQ (per defecte: guest)
 * - RABBITMQ_PASS: Contrasenya de RabbitMQ (per defecte: guest)
 * - QUEUE_NAME: Nom de la cua (per defecte: tasks)
 */

const amqp = require('amqplib');

// Configuració des de variables d'entorn
const config = {
    host: process.env.RABBITMQ_HOST || 'localhost',
    port: parseInt(process.env.RABBITMQ_PORT || '5672', 10),
    user: process.env.RABBITMQ_USER || 'guest',
    pass: process.env.RABBITMQ_PASS || 'guest',
    queue: process.env.QUEUE_NAME || 'tasks',
};

// Construir URL de connexió
const connectionUrl = `amqp://${config.user}:${config.pass}@${config.host}:${config.port}`;

// Temps d'espera entre reintents de connexió (ms)
const RETRY_INTERVAL = 5000;
const MAX_RETRIES = 12;

/**
 * Processa un missatge de la cua.
 * Aquesta funció es pot modificar per fer accions reals.
 */
async function processMessage(message) {
    const content = message.content.toString();
    const timestamp = new Date().toISOString();

    console.log(`[${timestamp}] Missatge rebut:`);

    try {
        // Intentar parsejar com a JSON
        const data = JSON.parse(content);
        console.log('  Tipus:', data.type || 'desconegut');
        console.log('  Dades:', JSON.stringify(data, null, 2));

        // Simular processament
        await simulateProcessing(data);

        console.log('  Estat: Processat correctament ✓');
        return true;
    } catch (error) {
        // Si no és JSON, mostrar com a text
        console.log('  Contingut:', content);
        console.log('  Estat: Processat com a text ✓');
        return true;
    }
}

/**
 * Simula el processament d'una tasca.
 * En un cas real, aquí es farien les accions necessàries.
 */
async function simulateProcessing(data) {
    // Simular temps de processament (100-500ms)
    const processingTime = Math.floor(Math.random() * 400) + 100;
    await new Promise(resolve => setTimeout(resolve, processingTime));

    // Exemples d'accions segons el tipus de tasca
    switch (data.type) {
        case 'email':
            console.log(`  Acció: Enviaria email a ${data.to || 'destinatari desconegut'}`);
            break;
        case 'notification':
            console.log(`  Acció: Enviaria notificació: ${data.message || 'sense missatge'}`);
            break;
        case 'report':
            console.log(`  Acció: Generaria informe: ${data.name || 'sense nom'}`);
            break;
        default:
            console.log('  Acció: Tasca genèrica processada');
    }
}

/**
 * Connecta a RabbitMQ amb reintents.
 */
async function connectWithRetry(retries = 0) {
    try {
        console.log(`Connectant a RabbitMQ (${config.host}:${config.port})...`);
        const connection = await amqp.connect(connectionUrl);
        console.log('Connexió establerta ✓');
        return connection;
    } catch (error) {
        if (retries < MAX_RETRIES) {
            console.log(`Error de connexió. Reintentant en ${RETRY_INTERVAL / 1000}s... (${retries + 1}/${MAX_RETRIES})`);
            await new Promise(resolve => setTimeout(resolve, RETRY_INTERVAL));
            return connectWithRetry(retries + 1);
        }
        throw new Error(`No s'ha pogut connectar a RabbitMQ després de ${MAX_RETRIES} intents: ${error.message}`);
    }
}

/**
 * Inicia el worker.
 */
async function startWorker() {
    console.log('='.repeat(50));
    console.log('Sports Club - Worker de RabbitMQ');
    console.log('='.repeat(50));
    console.log('');
    console.log('Configuració:');
    console.log(`  Host: ${config.host}`);
    console.log(`  Port: ${config.port}`);
    console.log(`  Usuari: ${config.user}`);
    console.log(`  Cua: ${config.queue}`);
    console.log('');

    let connection;
    let channel;

    try {
        // Connectar a RabbitMQ
        connection = await connectWithRetry();

        // Crear canal
        channel = await connection.createChannel();
        console.log('Canal creat ✓');

        // Assegurar que la cua existeix
        await channel.assertQueue(config.queue, {
            durable: true,
        });
        console.log(`Cua '${config.queue}' preparada ✓`);

        // Configurar prefetch (processar un missatge a la vegada)
        await channel.prefetch(1);

        console.log('');
        console.log('Esperant missatges... (Ctrl+C per sortir)');
        console.log('-'.repeat(50));

        // Consumir missatges
        await channel.consume(config.queue, async (message) => {
            if (message) {
                try {
                    const success = await processMessage(message);
                    if (success) {
                        channel.ack(message);
                    } else {
                        // Rebutjar i tornar a encuar
                        channel.nack(message, false, true);
                    }
                } catch (error) {
                    console.error('Error processant missatge:', error.message);
                    // Rebutjar sense tornar a encuar
                    channel.nack(message, false, false);
                }
            }
        });

        // Gestionar tancament graciós
        process.on('SIGINT', async () => {
            console.log('\n\nTancant connexió...');
            await channel.close();
            await connection.close();
            console.log('Connexió tancada. Adéu!');
            process.exit(0);
        });

        process.on('SIGTERM', async () => {
            console.log('\n\nRebut SIGTERM. Tancant...');
            await channel.close();
            await connection.close();
            process.exit(0);
        });

    } catch (error) {
        console.error('Error fatal:', error.message);
        process.exit(1);
    }
}

// Iniciar el worker
startWorker();
