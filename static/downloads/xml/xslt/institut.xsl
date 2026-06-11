<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <!-- Configuració de sortida HTML5 -->
    <xsl:output 
        method="html" 
        encoding="UTF-8" 
        indent="yes"
        doctype-system="about:legacy-compat"/>
    
    <!-- Variables globals -->
    <xsl:variable name="total-hores" select="sum(//assignatura/hores)"/>
    <xsl:variable name="total-alumnes" select="count(//alumne)"/>
    
    <!-- Plantilla principal (arrel) -->
    <xsl:template match="/">
        <html lang="ca">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                <title><xsl:value-of select="institut/nom"/> - <xsl:value-of select="institut/curs/@id"/></title>
                <style>
                    /* Estils incrustats per simplicitat */
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body { 
                        font-family: 'Segoe UI', Roboto, Arial, sans-serif; 
                        line-height: 1.6; 
                        background: #f4f4f4; 
                        padding: 20px;
                    }
                    .container { 
                        max-width: 1000px; 
                        margin: 0 auto; 
                        background: white; 
                        padding: 30px; 
                        border-radius: 10px; 
                        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                    }
                    header { 
                        text-align: center; 
                        border-bottom: 3px solid #2c3e50; 
                        padding-bottom: 20px; 
                        margin-bottom: 30px;
                    }
                    header h1 { color: #2c3e50; font-size: 2em; }
                    header .codi { color: #7f8c8d; font-size: 0.9em; }
                    header .curs { 
                        background: #3498db; 
                        color: white; 
                        padding: 5px 15px; 
                        border-radius: 20px; 
                        display: inline-block; 
                        margin-top: 10px;
                    }
                    .resum {
                        display: flex;
                        justify-content: space-around;
                        background: #ecf0f1;
                        padding: 15px;
                        border-radius: 8px;
                        margin-bottom: 30px;
                    }
                    .resum-item { text-align: center; }
                    .resum-item .valor { font-size: 2em; font-weight: bold; color: #2c3e50; }
                    .resum-item .etiqueta { color: #7f8c8d; font-size: 0.9em; }
                    section { margin-bottom: 30px; }
                    section h2 { 
                        color: #2c3e50; 
                        border-bottom: 2px solid #3498db; 
                        padding-bottom: 10px; 
                        margin-bottom: 20px;
                    }
                    /* Taula d'assignatures */
                    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
                    th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #ddd; }
                    th { background: #2c3e50; color: white; }
                    tr:hover { background: #f5f5f5; }
                    .codi-assig { 
                        background: #27ae60; 
                        color: white; 
                        padding: 3px 8px; 
                        border-radius: 4px; 
                        font-weight: bold;
                        font-size: 0.85em;
                    }
                    .hores { text-align: right; }
                    .hores-alta { color: #c0392b; font-weight: bold; }
                    .hores-mitjana { color: #f39c12; }
                    .hores-baixa { color: #27ae60; }
                    /* Graella d'alumnes */
                    .alumnes-grid { 
                        display: grid; 
                        grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); 
                        gap: 15px;
                    }
                    .alumne-card {
                        background: #fff;
                        border: 1px solid #ddd;
                        border-left: 4px solid #3498db;
                        border-radius: 0 8px 8px 0;
                        padding: 15px;
                        transition: transform 0.2s, box-shadow 0.2s;
                    }
                    .alumne-card:hover {
                        transform: translateY(-3px);
                        box-shadow: 0 4px 15px rgba(0,0,0,0.1);
                    }
                    .alumne-card .id { 
                        background: #3498db; 
                        color: white; 
                        padding: 2px 8px; 
                        border-radius: 4px; 
                        font-size: 0.75em;
                        float: right;
                    }
                    .alumne-card .nom-complet { 
                        font-weight: bold; 
                        color: #2c3e50; 
                        font-size: 1.1em;
                        margin-bottom: 5px;
                    }
                    .alumne-card .email { 
                        color: #3498db; 
                        font-size: 0.9em;
                        text-decoration: none;
                    }
                    .alumne-card .email:hover { text-decoration: underline; }
                    .alumne-card .edat { 
                        color: #7f8c8d; 
                        font-size: 0.85em;
                        margin-top: 5px;
                    }
                    footer {
                        text-align: center;
                        color: #7f8c8d;
                        font-size: 0.85em;
                        margin-top: 30px;
                        padding-top: 20px;
                        border-top: 1px solid #ddd;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <xsl:apply-templates select="institut"/>
                </div>
            </body>
        </html>
    </xsl:template>
    
    <!-- Plantilla: institut -->
    <xsl:template match="institut">
        <header>
            <h1><xsl:value-of select="nom"/></h1>
            <p class="codi">Codi del centre: <xsl:value-of select="codi"/></p>
            <p>Any acadèmic: <xsl:value-of select="any-academic"/></p>
            <span class="curs">
                <xsl:value-of select="curs/@id"/> - <xsl:value-of select="curs/@nom"/>
            </span>
        </header>
        
        <!-- Resum estadístic -->
        <div class="resum">
            <div class="resum-item">
                <div class="valor"><xsl:value-of select="$total-alumnes"/></div>
                <div class="etiqueta">Alumnes matriculats</div>
            </div>
            <div class="resum-item">
                <div class="valor"><xsl:value-of select="count(//assignatura)"/></div>
                <div class="etiqueta">Assignatures</div>
            </div>
            <div class="resum-item">
                <div class="valor"><xsl:value-of select="$total-hores"/></div>
                <div class="etiqueta">Hores totals</div>
            </div>
        </div>
        
        <xsl:apply-templates select="curs/assignatures"/>
        <xsl:apply-templates select="curs/alumnes"/>
        
        <footer>
            <p>Document generat mitjançant transformació XSLT</p>
            <p><xsl:value-of select="nom"/> © <xsl:value-of select="substring(any-academic, 1, 4)"/></p>
        </footer>
    </xsl:template>
    
    <!-- Plantilla: assignatures -->
    <xsl:template match="assignatures">
        <section>
            <h2>📚 Assignatures del curs</h2>
            <table>
                <thead>
                    <tr>
                        <th>Codi</th>
                        <th>Nom de l'assignatura</th>
                        <th class="hores">Hores</th>
                        <th>Càrrega</th>
                    </tr>
                </thead>
                <tbody>
                    <xsl:for-each select="assignatura">
                        <xsl:sort select="hores" data-type="number" order="descending"/>
                        <tr>
                            <td><span class="codi-assig"><xsl:value-of select="@codi"/></span></td>
                            <td><xsl:value-of select="nom"/></td>
                            <td class="hores"><xsl:value-of select="hores"/>h</td>
                            <td>
                                <xsl:choose>
                                    <xsl:when test="hores >= 120">
                                        <span class="hores-alta">Alta</span>
                                    </xsl:when>
                                    <xsl:when test="hores >= 80">
                                        <span class="hores-mitjana">Mitjana</span>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <span class="hores-baixa">Baixa</span>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </td>
                        </tr>
                    </xsl:for-each>
                </tbody>
            </table>
        </section>
    </xsl:template>
    
    <!-- Plantilla: alumnes -->
    <xsl:template match="alumnes">
        <section>
            <h2>👥 Alumnes matriculats</h2>
            <div class="alumnes-grid">
                <xsl:for-each select="alumne">
                    <xsl:sort select="cognoms"/>
                    <xsl:sort select="nom"/>
                    <div class="alumne-card">
                        <span class="id"><xsl:value-of select="@id"/></span>
                        <div class="nom-complet">
                            <xsl:value-of select="cognoms"/>, <xsl:value-of select="nom"/>
                        </div>
                        <a class="email" href="mailto:{email}">
                            <xsl:value-of select="email"/>
                        </a>
                        <div class="edat">
                            Naixement: <xsl:value-of select="data-naixement"/>
                        </div>
                    </div>
                </xsl:for-each>
            </div>
        </section>
    </xsl:template>
    
</xsl:stylesheet>
