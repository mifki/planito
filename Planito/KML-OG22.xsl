<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:n="http://www.opengis.net/kml/2.2" version="1.0">
    <xsl:output method="xml" indent="no"/>

    <xsl:template match="/">
        <features>
            <xsl:apply-templates select="//n:Placemark"/>
        </features>
    </xsl:template>
 
    <xsl:template match="n:Placemark">
        <pm>
            <xsl:variable name="coords"><xsl:value-of select="normalize-space(n:Point/n:coordinates)"/></xsl:variable>
            <xsl:variable name="coords2"><xsl:value-of select="substring-after($coords,',')"/></xsl:variable>
            <xsl:choose>
                <xsl:when test="contains($coords2,',')">
                    <xsl:attribute name="c"><xsl:value-of select="substring-before($coords2,',')" /><xsl:text>,</xsl:text><xsl:value-of select="substring-before($coords,',')" /></xsl:attribute>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="c"><xsl:value-of select="$coords2" /><xsl:text>,</xsl:text><xsl:value-of select="substring-before($coords,',')" /></xsl:attribute>
                </xsl:otherwise>
            </xsl:choose>

            <xsl:attribute name="s"><xsl:value-of select="normalize-space(n:styleUrl)" /></xsl:attribute>

            <t><xsl:value-of select="normalize-space(n:name)" /></t>
            <d><xsl:value-of select="normalize-space(n:description)" /></d>
        </pm>
    </xsl:template>
</xsl:stylesheet>
