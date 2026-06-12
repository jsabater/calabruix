/**
 * Worker de RabbitMQ per a Sports Club
 *
 * Aquest worker consumeix missatges de la cua 'tasks' de RabbitMQ,
 * consulta l'API per obtenir dades i envia emails via Mailpit.
 *
 * Variables d'entorn requerides:
 * - RABBITMQ_HOST: Host de RabbitMQ (per defecte: localhost)
 * - RABBITMQ_PORT: Port de RabbitMQ (per defecte: 5672)
 * - RABBITMQ_USER: Usuari de RabbitMQ (per defecte: guest)
 * - RABBITMQ_PASS: Contrasenya de RabbitMQ (per defecte: guest)
 * - QUEUE_NAME: Nom de la cua (per defecte: tasks)
 * - API_HOST: Host de l'API (per defecte: localhost)
 * - API_PORT: Port de l'API (per defecte: 8080)
 * - SMTP_HOST: Host del servidor SMTP (per defecte: localhost)
 * - SMTP_PORT: Port del servidor SMTP (per defecte: 1025)
 * - EMAIL_FROM: Adreça d'email del remitent (per defecte: noreply@sportsclub.local)
 */

const amqp = require('amqplib');
const nodemailer = require('nodemailer');

// Configuració des de variables d'entorn
const config = {
    rabbitmq: {
        host: process.env.RABBITMQ_HOST || 'localhost',
        port: parseInt(process.env.RABBITMQ_PORT || '5672', 10),
        user: process.env.RABBITMQ_USER || 'guest',
        pass: process.env.RABBITMQ_PASS || 'guest',
        queue: process.env.QUEUE_NAME || 'tasks',
    },
    api: {
        host: process.env.API_HOST || 'localhost',
        port: parseInt(process.env.API_PORT || '8080', 10),
    },
    smtp: {
        host: process.env.SMTP_HOST || 'localhost',
        port: parseInt(process.env.SMTP_PORT || '1025', 10),
    },
    email: {
        from: process.env.EMAIL_FROM || 'noreply@sportsclub.local',
    },
};

// Construir URL de connexió a RabbitMQ
const rabbitUrl = `amqp://${config.rabbitmq.user}:${config.rabbitmq.pass}@${config.rabbitmq.host}:${config.rabbitmq.port}`;

// Configurar transport de correu (Mailpit)
const mailTransport = nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.port,
    secure: false,
});

// Temps d'espera entre reintents de connexió (ms)
const RETRY_INTERVAL = 5000;
const MAX_RETRIES = 12;

/**
 * Obté les dades d'un atleta de l'API.
 */
async function getAthlete(publicId) {
    const url = `http://${config.api.host}:${config.api.port}/api/v1/people/athletes/${publicId}`;
    
    const response = await fetch(url);
    
    if (!response.ok) {
        throw new Error(`Error obtenint atleta ${publicId}: ${response.status} ${response.statusText}`);
    }
    
    return await response.json();
}

/**
 * Envia un email de benvinguda a un atleta.
 */
async function sendWelcomeEmail(athlete) {
    const emailContent = {
        from: config.email.from,
        to: athlete.email || 'athlete@sportsclub.local',
        subject: `Benvingut/da a Sports Club, ${athlete.first_name}!`,
        text: `
Hola ${athlete.first_name} ${athlete.last_name},

Benvingut/da a Sports Club!

Les teves dades al sistema són:
- Identificador: ${athlete.public_id}
- Nom: ${athlete.first_name} ${athlete.last_name}
- Email: ${athlete.email || 'No especificat'}

Gràcies per unir-te al club!

Atentament,
L'equip de Sports Club
        `.trim(),
        html: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <h2 style="color: #2563eb;">Benvingut/da a Sports Club!</h2>
    
    <p>Hola <strong>${athlete.first_name} ${athlete.last_name}</strong>,</p>
    
    <p>Benvingut/da a Sports Club!</p>
    
    <p>Les teves dades al sistema són:</p>
    <ul>
        <li><strong>Identificador:</strong> ${athlete.public_id}</li>
        <li><strong>Nom:</strong> ${athlete.first_name} ${athlete.last_name}</li>
        <li><strong>Email:</strong> ${athlete.email || 'No especificat'}</li>
    </ul>
    
    <p>Gràcies per unir-te al club!</p>
    
    <p>Atentament,<br>
    <em>L'equip de Sports Club</em></p>
</body>
</html>
        `.trim(),
    };

    const result = await mailTransport.sendMail(emailContent);
    return result;
}

/**
 * Processa un missatge de la cua.
 */
async function processMessage(message) {
    const content = message.content.toString();
    const timestamp = new Date().toISOString();

    console.log(`[${timestamp}] Missatge rebut: ${content}`);

    let data;
    try {
        data = JSON.parse(content);
    } catch (error) {
        console.error('  Error: El missatge no és un JSON vàlid');
        return false;
    }

    // Validar format del missatge
    if (data.type !== 'email') {
        console.log(`  Tipus '${data.type}' no suportat. Ignorant.`);
        return true;
    }

    if (data.target !== 'athlete') {
        console.log(`  Target '${data.target}' no suportat. Ignorant.`);
        return true;
    }

    if (!data.public_id) {
        console.error('  Error: Falta el camp public_id');
        return false;
    }

    try {
        // Obtenir dades de l'atleta
        console.log(`  Obtenint dades de l'atleta ${data.public_id}...`);
        const athlete = await getAthlete(data.public_id);
        console.log(`  Atleta trobat: ${athlete.first_name} ${athlete.last_name}`);

        // Enviar email segons el subtipus
        if (data.subtype === 'welcome') {
            console.log(`  Enviant email de benvinguda...`);
            const result = await sendWelcomeEmail(athlete);
            console.log(`  Email enviat correctament (ID: ${result.messageId})`);
        } else {
            console.log(`  Subtipus '${data.subtype}' no suportat. Ignorant.`);
        }

        console.log('  Processament completat ✓');
        return true;

    } catch (error) {
        console.error(`  Error processant missatge: ${error.message}`);
        return false;
    }
}

/**
 * Connecta a RabbitMQ amb reintents.
 */
async function connectWithRetry(retries = 0) {
    try {
        console.log(`Connectant a RabbitMQ (${config.rabbitmq.host}:${config.rabbitmq.port})...`);
        const connection = await amqp.connect(rabbitUrl);
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
    console.log('='.repeat(60));
    console.log('Sports Club - Worker de RabbitMQ');
    console.log('='.repeat(60));
    console.log('');
    console.log('Configuració:');
    console.log(`  RabbitMQ: ${config.rabbitmq.host}:${config.rabbitmq.port}`);
    console.log(`  Cua: ${config.rabbitmq.queue}`);
    console.log(`  API: ${config.api.host}:${config.api.port}`);
    console.log(`  SMTP: ${config.smtp.host}:${config.smtp.port}`);
    console.log('');

    let connection;
    let channel;

    try {
        // Connectar a RabbitMQ
        connection = await connectWithRetry();

        // Gestionar errors de connexió
        connection.on('error', (err) => {
            console.error('Error de connexió RabbitMQ:', err.message);
        });

        connection.on('close', () => {
            console.log('Connexió RabbitMQ tancada');
            process.exit(1);
        });

        // Crear canal
        channel = await connection.createChannel();
        console.log('Canal creat ✓');

        // Assegurar que la cua existeix
        await channel.assertQueue(config.rabbitmq.queue, {
            durable: true,
        });
        console.log(`Cua '${config.rabbitmq.queue}' preparada ✓`);

        // Verificar connexió SMTP
        try {
            await mailTransport.verify();
            console.log('Connexió SMTP verificada ✓');
        } catch (error) {
            console.warn(`Avís: No s'ha pogut verificar SMTP (${error.message}). Els emails podrien fallar.`);
        }

        // Configurar prefetch (processar un missatge a la vegada)
        await channel.prefetch(1);

        console.log('');
        console.log('Esperant missatges... (Ctrl+C per sortir)');
        console.log('-'.repeat(60));

        // Consumir missatges
        await channel.consume(config.rabbitmq.queue, async (message) => {
            if (message) {
                try {
                    const success = await processMessage(message);
                    if (success) {
                        channel.ack(message);
                    } else {
                        // Rebutjar sense tornar a encuar (missatge invàlid)
                        channel.nack(message, false, false);
                    }
                } catch (error) {
                    console.error('Error inesperat processant missatge:', error.message);
                    channel.nack(message, false, false);
                }
            }
        });

        // Gestionar tancament graciós
        const shutdown = async () => {
            console.log('\n\nTancant connexions...');
            try {
                await channel.close();
                await connection.close();
                console.log('Connexions tancades. Adéu!');
            } catch (error) {
                console.error('Error tancant connexions:', error.message);
            }
            process.exit(0);
        };

        process.on('SIGINT', shutdown);
        process.on('SIGTERM', shutdown);

    } catch (error) {
        console.error('Error fatal:', error.message);
        process.exit(1);
    }
}

// Iniciar el worker
startWorker();
