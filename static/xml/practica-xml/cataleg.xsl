<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:cat="http://exemple.com/cataleg"
                xmlns:joc="http://exemple.com/videojoc"
                exclude-result-prefixes="cat joc">

    <xsl:output method="html" encoding="UTF-8" indent="yes"/>

    <!-- Variables globals -->
    <xsl:variable name="totalJocs" select="count(//joc:videojoc)"/>
    <xsl:variable name="mitjana" select="sum(//joc:puntuacio) div $totalJocs"/>

    <!-- Plantilla principal -->
    <xsl:template match="/">
        <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
        <html lang="ca">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                <title><xsl:value-of select="//cat:info/cat:titol"/></title>
                <style>
                    :root {
                        --color-fons: #1b2838;
                        --color-fons-targeta: #2a475e;
                        --color-text: #c7d5e0;
                        --color-accent: #66c0f4;
                        --color-preu: #a4d007;
                        --color-puntuacio: #ffcc00;
                    }
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        font-family: 'Segoe UI', Roboto, Arial, sans-serif;
                        background-color: var(--color-fons);
                        color: var(--color-text);
                        line-height: 1.6;
                        padding: 2rem;
                    }
                    header {
                        text-align: center;
                        margin-bottom: 2rem;
                        padding-bottom: 1rem;
                        border-bottom: 2px solid var(--color-accent);
                    }
                    header h1 { color: var(--color-accent); margin-bottom: 0.5rem; }
                    .meta { font-size: 0.9rem; opacity: 0.8; }
                    .estadistiques {
                        display: flex;
                        justify-content: center;
                        gap: 2rem;
                        margin: 1rem 0;
                        padding: 1rem;
                        background-color: var(--color-fons-targeta);
                        border-radius: 0.5rem;
                    }
                    .estadistiques span { font-weight: bold; color: var(--color-accent); }
                    .videojocs {
                        display: grid;
                        grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
                        gap: 1.5rem;
                        margin-top: 2rem;
                    }
                    .videojoc {
                        background-color: var(--color-fons-targeta);
                        border-radius: 0.5rem;
                        padding: 1.5rem;
                        transition: transform 0.2s ease;
                    }
                    .videojoc:hover { transform: translateY(-4px); }
                    .videojoc h2 {
                        color: var(--color-accent);
                        font-size: 1.4rem;
                        margin-bottom: 0.5rem;
                    }
                    .videojoc .descripcio {
                        font-size: 0.9rem;
                        margin-bottom: 1rem;
                        opacity: 0.9;
                    }
                    .info-linia {
                        font-size: 0.85rem;
                        margin: 0.25rem 0;
                    }
                    .etiqueta {
                        display: inline-block;
                        background-color: var(--color-fons);
                        padding: 0.2rem 0.6rem;
                        border-radius: 1rem;
                        font-size: 0.75rem;
                        margin: 0.2rem;
                    }
                    .plataforma {
                        display: inline-block;
                        background-color: var(--color-accent);
                        color: var(--color-fons);
                        padding: 0.2rem 0.6rem;
                        border-radius: 1rem;
                        font-size: 0.75rem;
                        margin: 0.2rem;
                    }
                    .preu {
                        font-size: 1.3rem;
                        font-weight: bold;
                        color: var(--color-preu);
                        margin: 0.75rem 0;
                    }
                    .puntuacio {
                        color: var(--color-puntuacio);
                        font-weight: bold;
                    }
                    .puntuacio-excellent { color: #66ff66; }
                    .puntuacio-bo { color: var(--color-puntuacio); }
                    .puntuacio-regular { color: #ff9966; }
                    .puntuacio-baix { color: #ff6666; }
                    .requisits {
                        background-color: var(--color-fons);
                        padding: 0.75rem;
                        border-radius: 0.25rem;
                        margin: 0.75rem 0;
                        font-size: 0.8rem;
                    }
                    .requisits h4 { margin-bottom: 0.5rem; }
                    .dlcs {
                        margin-top: 1rem;
                        padding-top: 0.75rem;
                        border-top: 1px solid var(--color-fons);
                    }
                    .dlc {
                        font-size: 0.85rem;
                        padding: 0.25rem 0;
                    }
                    .gratuit { color: var(--color-preu); }
                </style>
            </head>
            <body>
                <header>
                    <h1><xsl:value-of select="//cat:info/cat:titol"/></h1>
                    <p class="meta">
                        Autor: <xsl:value-of select="//cat:info/cat:autor"/> |
                        Actualitzat: <xsl:value-of select="//cat:info/cat:actualitzat"/>
                    </p>
                    <p class="meta">
                        <xsl:value-of select="//cat:info/cat:descripcio[@xml:lang='ca']"/>
                    </p>
                    <div class="estadistiques">
                        <div>Total de jocs: <span><xsl:value-of select="$totalJocs"/></span></div>
                        <div>Puntuació mitjana: <span><xsl:value-of select="format-number($mitjana, '#.#')"/>/100</span></div>
                    </div>
                </header>

                <main class="videojocs">
                    <xsl:apply-templates select="//joc:videojoc">
                        <xsl:sort select="joc:puntuacio" data-type="number" order="descending"/>
                    </xsl:apply-templates>
                </main>
            </body>
        </html>
    </xsl:template>

    <!-- Plantilla per a cada videojoc -->
    <xsl:template match="joc:videojoc">
        <article class="videojoc" id="{@id}">
            <h2><xsl:value-of select="joc:titol"/></h2>
            <p class="descripcio">
                <xsl:value-of select="joc:descripcio[@xml:lang='ca']"/>
            </p>

            <p class="info-linia">
                <strong>Desenvolupador:</strong> <xsl:value-of select="joc:desenvolupador"/>
            </p>
            <p class="info-linia">
                <strong>Distribuïdor:</strong> <xsl:value-of select="joc:distribuidor"/>
            </p>
            <p class="info-linia">
                <strong>Llançament:</strong> <xsl:value-of select="joc:dataLlancament"/>
            </p>

            <div class="info-linia">
                <strong>Gèneres: </strong>
                <xsl:for-each select="joc:generes/joc:genere">
                    <span class="etiqueta"><xsl:value-of select="."/></span>
                </xsl:for-each>
            </div>

            <div class="info-linia">
                <strong>Plataformes: </strong>
                <xsl:for-each select="joc:plataformes/joc:plataforma">
                    <span class="plataforma"><xsl:value-of select="."/></span>
                </xsl:for-each>
            </div>

            <p class="preu">
                <xsl:value-of select="joc:preu"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="joc:preu/@moneda"/>
            </p>

            <p class="info-linia">
                <strong>Puntuació: </strong>
                <span>
                    <xsl:attribute name="class">
                        <xsl:text>puntuacio </xsl:text>
                        <xsl:choose>
                            <xsl:when test="joc:valoracions/joc:puntuacio >= 90">puntuacio-excellent</xsl:when>
                            <xsl:when test="joc:valoracions/joc:puntuacio >= 70">puntuacio-bo</xsl:when>
                            <xsl:when test="joc:valoracions/joc:puntuacio >= 50">puntuacio-regular</xsl:when>
                            <xsl:otherwise>puntuacio-baix</xsl:otherwise>
                        </xsl:choose>
                    </xsl:attribute>
                    <xsl:value-of select="joc:valoracions/joc:puntuacio"/>/100
                </span>
                (<xsl:value-of select="format-number(joc:valoracions/joc:numRessenyes, '#,###')"/> ressenyes)
            </p>

            <div class="requisits">
                <h4>💻 Requisits mínims</h4>
                <p><strong>SO:</strong> <xsl:value-of select="joc:requisits/joc:so"/></p>
                <p><strong>CPU:</strong> <xsl:value-of select="joc:requisits/joc:cpu"/></p>
                <p><strong>RAM:</strong> <xsl:value-of select="joc:requisits/joc:ram"/> GB</p>
                <p><strong>VRAM:</strong> <xsl:value-of select="joc:requisits/joc:vram"/> MB</p>
                <p><strong>Disc:</strong> <xsl:value-of select="joc:requisits/joc:disc"/> GB</p>
            </div>

            <div class="info-linia">
                <strong>Etiquetes: </strong>
                <xsl:for-each select="joc:etiquetes/joc:etiqueta">
                    <span class="etiqueta"><xsl:value-of select="."/></span>
                </xsl:for-each>
            </div>

            <xsl:if test="joc:dlcs">
                <div class="dlcs">
                    <strong>📦 Contingut addicional:</strong>
                    <xsl:for-each select="joc:dlcs/joc:dlc">
                        <p class="dlc">
                            <xsl:value-of select="joc:nom"/>
                            <xsl:choose>
                                <xsl:when test="@gratuit = 'true'">
                                    <span class="gratuit"> ✓ Gratuït</span>
                                </xsl:when>
                                <xsl:otherwise>
                                    <span> 💰 De pagament</span>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:for-each>
                </div>
            </xsl:if>
        </article>
    </xsl:template>

</xsl:stylesheet>
